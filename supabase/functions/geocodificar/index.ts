// Convierte texto en coordenadas con Nominatim (OpenStreetMap), limitado a Dolores Hidalgo.
// Política de uso de Nominatim: máximo 1 consulta por segundo e identificarse con User-Agent.
// Por eso se cachea cada búsqueda 30 días.
// Entrada: { "q": "hospital general" }
// Salida:  [{ "nombre": "...", "lat": 21.15, "lng": -100.93 }]
import { cors, guardarCache, json, leerCache } from "../_shared/comun.ts";

// Recuadro alrededor de la ciudad (oeste, norte, este, sur)
const VIEWBOX = "-101.02,21.22,-100.85,21.09";
let ultimaConsulta = 0;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { q } = await req.json();
    const texto = String(q ?? "").trim().toLowerCase();
    if (texto.length < 3 || texto.length > 100) {
      return json({ error: "Escribe entre 3 y 100 caracteres" }, 400);
    }

    const clave = `geo:${texto}`;
    const enCache = await leerCache(clave);
    if (enCache) return json(enCache);

    const espera = 1100 - (Date.now() - ultimaConsulta);
    if (espera > 0) await new Promise((r) => setTimeout(r, espera));
    ultimaConsulta = Date.now();

    const url = new URL("https://nominatim.openstreetmap.org/search");
    url.searchParams.set("q", `${texto}, Dolores Hidalgo, Guanajuato`);
    url.searchParams.set("format", "jsonv2");
    url.searchParams.set("limit", "5");
    url.searchParams.set("countrycodes", "mx");
    url.searchParams.set("viewbox", VIEWBOX);
    url.searchParams.set("bounded", "1");
    url.searchParams.set("accept-language", "es");

    const resp = await fetch(url, {
      headers: {
        "User-Agent": `CamionesDolores/1.0 (${Deno.env.get("CONTACTO_NOMINATIM") ?? "proyecto escolar"})`,
      },
    });
    if (!resp.ok) return json({ error: `Nominatim respondió ${resp.status}` }, 502);

    const lista = await resp.json();
    const resultado = (lista as Array<Record<string, string>>).map((x) => ({
      nombre: x.display_name.split(",").slice(0, 3).join(",").trim(),
      lat: Number(x.lat),
      lng: Number(x.lon),
    }));
    await guardarCache(clave, resultado);
    return json(resultado);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
