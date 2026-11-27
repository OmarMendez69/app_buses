// Envía notificaciones push con Firebase Cloud Messaging (API HTTP v1).
// La llaman los Database Webhooks de Supabase al insertar en:
//   · aviso_servicio → topic "ruta_<id>" o "general"
//   · comentario     → al autor de la publicación, en sus dispositivos
// Secretos necesarios:
//   FCM_SERVICE_ACCOUNT  JSON completo de la cuenta de servicio de Firebase
//   WEBHOOK_SECRET       texto que el webhook manda en el encabezado x-webhook-secret
import { clienteServicio, cors, json } from "../_shared/comun.ts";

type CuentaServicio = { project_id: string; client_email: string; private_key: string };

let tokenCache: { valor: string; vence: number } | null = null;

function base64url(datos: ArrayBuffer | string): string {
  const bytes = typeof datos === "string" ? new TextEncoder().encode(datos) : new Uint8Array(datos);
  let bin = "";
  bytes.forEach((b) => (bin += String.fromCharCode(b)));
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function tokenGoogle(cuenta: CuentaServicio): Promise<string> {
  if (tokenCache && tokenCache.vence > Date.now() + 60_000) return tokenCache.valor;

  const ahora = Math.floor(Date.now() / 1000);
  const encabezado = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const cuerpo = base64url(JSON.stringify({
    iss: cuenta.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: ahora,
    exp: ahora + 3600,
  }));

  const pem = cuenta.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const llave = await crypto.subtle.importKey(
    "pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const firma = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", llave, new TextEncoder().encode(`${encabezado}.${cuerpo}`));
  const jwt = `${encabezado}.${cuerpo}.${base64url(firma)}`;

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  if (!resp.ok) throw new Error(`Google OAuth respondió ${resp.status}: ${await resp.text()}`);
  const datos = await resp.json();
  tokenCache = { valor: datos.access_token, vence: Date.now() + datos.expires_in * 1000 };
  return datos.access_token;
}

async function enviar(
  cuenta: CuentaServicio,
  destino: { topic: string } | { token: string },
  titulo: string,
  cuerpo: string,
  datos: Record<string, string>,
  canal: string,
): Promise<number> {
  const token = await tokenGoogle(cuenta);
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${cuenta.project_id}/messages:send`,
    {
      method: "POST",
      headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          ...destino,
          notification: { title: titulo, body: cuerpo },
          data: datos,
          android: { priority: "high", notification: { channel_id: canal } },
        },
      }),
    },
  );
  if (!resp.ok) console.error("FCM", resp.status, await resp.text());
  return resp.status;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const secreto = Deno.env.get("WEBHOOK_SECRET");
  if (!secreto || req.headers.get("x-webhook-secret") !== secreto) {
    return json({ error: "No autorizado" }, 401);
  }

  try {
    const cuenta: CuentaServicio = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");
    const { type, table, record } = await req.json();
    if (type !== "INSERT" || !record) return json({ ok: true, omitido: "sin cambios" });
    const db = clienteServicio();

    if (table === "aviso_servicio") {
      if (!record.notificar) return json({ ok: true, omitido: "aviso sin notificación" });
      const topic = record.id_ruta ? `ruta_${record.id_ruta}` : "general";
      const detalle = String(record.detalle ?? "");
      const status = await enviar(
        cuenta,
        { topic },
        record.titulo,
        detalle.length > 150 ? detalle.slice(0, 147) + "..." : detalle,
        { tipo: "aviso", id_aviso: String(record.id_aviso), id_ruta: String(record.id_ruta ?? "") },
        "avisos",
      );
      if (status === 200) {
        await db.from("aviso_servicio").update({ notificado: true }).eq("id_aviso", record.id_aviso);
      }
      return json({ ok: status === 200, topic });
    }

    if (table === "comentario") {
      const { data: pub } = await db
        .from("publicacion")
        .select("id_usuario, texto")
        .eq("id_publicacion", record.id_publicacion)
        .maybeSingle();
      if (!pub?.id_usuario || pub.id_usuario === record.id_usuario) {
        return json({ ok: true, omitido: "sin destinatario" });
      }
      const { data: autor } = await db
        .from("perfil").select("notif_respuestas, idioma").eq("id", pub.id_usuario).maybeSingle();
      if (!autor?.notif_respuestas) return json({ ok: true, omitido: "autor no quiere avisos" });

      const { data: tokens } = await db.from("dispositivo").select("token_fcm").eq("id_usuario", pub.id_usuario);
      const titulo = autor.idioma === "en" ? "New reply to your post" : "Nueva respuesta a tu publicación";
      let enviados = 0;
      for (const t of tokens ?? []) {
        const status = await enviar(
          cuenta,
          { token: t.token_fcm },
          titulo,
          String(record.texto).slice(0, 150),
          { tipo: "comentario", id_publicacion: String(record.id_publicacion) },
          "tablon",
        );
        if (status === 404 || status === 400) {
          await db.from("dispositivo").delete().eq("token_fcm", t.token_fcm); // token vencido
        } else if (status === 200) {
          enviados++;
        }
      }
      return json({ ok: true, enviados });
    }

    return json({ ok: true, omitido: `tabla ${table} no manejada` });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
