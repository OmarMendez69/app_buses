// Caminata real por calles con OpenRouteService (perfil foot-walking).
// La llave de ORS vive como secreto (ORS_API_KEY) y nunca llega al teléfono.
// Entrada:  { "origen": [lng, lat], "destino": [lng, lat] }
// Salida:   { "distancia_m": 420, "duracion_s": 330, "coords": [[lng, lat], ...] }
import { cors, guardarCache, json, leerCache } from "../_shared/comun.ts";

function valido(p: unknown): p is [number, number] {
  return Array.isArray(p) && p.length === 2 &&
    typeof p[0] === "number" && typeof p[1] === "number" &&
    p[0] > -101.6 && p[0] < -100.3 && p[1] > 20.6 && p[1] < 21.8;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { origen, destino } = await req.json();
    if (!valido(origen) || !valido(destino)) {
      return json({ error: "Coordenadas fuera de la zona de Dolores Hidalgo" }, 400);
    }

    const r5 = (n: number) => n.toFixed(5);
    const clave = `pie:${r5(origen[0])},${r5(origen[1])}:${r5(destino[0])},${r5(destino[1])}`;
    const enCache = await leerCache(clave);
    if (enCache) return json(enCache);

    const resp = await fetch(
      "https://api.openrouteservice.org/v2/directions/foot-walking/geojson",
      {
        method: "POST",
        headers: {
          "Authorization": Deno.env.get("ORS_API_KEY") ?? "",
          "Content-Type": "application/json",
          "Accept": "application/geo+json",
        },
        body: JSON.stringify({ coordinates: [origen, destino] }),
      },
    );

    if (resp.status === 429) return json({ error: "Límite diario de OpenRouteService alcanzado" }, 429);
    if (!resp.ok) return json({ error: `OpenRouteService respondió ${resp.status}` }, 502);

    const geo = await resp.json();
    const f = geo.features?.[0];
    if (!f) return json({ error: "Sin ruta a pie" }, 404);

    const resultado = {
      distancia_m: Math.round(f.properties.summary.distance ?? 0),
      duracion_s: Math.round(f.properties.summary.duration ?? 0),
      coords: f.geometry.coordinates,
    };
    await guardarCache(clave, resultado);
    return json(resultado);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
