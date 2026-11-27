// Utilidades compartidas por las Edge Functions.
import { createClient } from "jsr:@supabase/supabase-js@2";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(datos: unknown, status = 200): Response {
  return new Response(JSON.stringify(datos), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// Cliente con service_role: ignora RLS. Solo vive en el servidor.
export function clienteServicio() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

const DIAS_CACHE = 30;

export async function leerCache(clave: string): Promise<unknown | null> {
  const db = clienteServicio();
  const { data } = await db
    .from("cache_api")
    .select("respuesta, creado_en")
    .eq("clave", clave)
    .maybeSingle();
  if (!data) return null;
  const edadDias = (Date.now() - new Date(data.creado_en).getTime()) / 86_400_000;
  return edadDias <= DIAS_CACHE ? data.respuesta : null;
}

export async function guardarCache(clave: string, respuesta: unknown): Promise<void> {
  const db = clienteServicio();
  await db.from("cache_api").upsert({ clave, respuesta, creado_en: new Date().toISOString() });
}
