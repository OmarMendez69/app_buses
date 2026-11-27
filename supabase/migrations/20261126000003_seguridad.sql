-- =====================================================================
-- Migración 3: permisos (Row Level Security), almacenamiento y tiempo real
-- =====================================================================

-- Supabase da acceso a las tablas a los roles anon y authenticated;
-- las políticas RLS deciden qué filas puede ver o cambiar cada quien.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
grant execute on all functions in schema public to anon, authenticated;

-- El perfil solo deja editar estas columnas desde la app (rol y estado van por RPC).
revoke update on public.perfil from anon, authenticated;
grant update (nombre, notif_rutas, notif_generales, notif_respuestas, idioma) on public.perfil to authenticated;

-- Las RPC de administración no se exponen al rol anónimo.
revoke execute on function public.guardar_recorrido(int, jsonb, jsonb) from anon;
revoke execute on function public.guardar_franjas(int, public.tipo_dia, jsonb) from anon;
revoke execute on function public.resolver_denuncia(int, boolean) from anon;
revoke execute on function public.admin_listar_usuarios() from anon;
revoke execute on function public.admin_actualizar_usuario(uuid, public.rol_usuario, public.estado_cuenta) from anon;
revoke execute on function public.metricas_admin() from anon;
revoke execute on function public.eliminar_mi_cuenta() from anon;
revoke execute on function public.aviso_automatico(int, public.tipo_aviso, text, text) from anon, authenticated;

alter table public.perfil           enable row level security;
alter table public.ruta             enable row level security;
alter table public.recorrido        enable row level security;
alter table public.parada           enable row level security;
alter table public.recorrido_parada enable row level security;
alter table public.franja_servicio  enable row level security;
alter table public.lugar            enable row level security;
alter table public.horario_lugar    enable row level security;
alter table public.aviso_servicio   enable row level security;
alter table public.aviso_parada     enable row level security;
alter table public.dia_especial     enable row level security;
alter table public.dispositivo      enable row level security;
alter table public.favorito         enable row level security;
alter table public.viaje_guardado   enable row level security;
alter table public.publicacion      enable row level security;
alter table public.comentario       enable row level security;
alter table public.voto_util        enable row level security;
alter table public.denuncia         enable row level security;
alter table public.bitacora_admin   enable row level security;
alter table public.cache_api        enable row level security; -- sin políticas: solo service_role

-- ---------------------------------------------------------------------
-- Perfil: nombres públicos (para el tablón); cada quien edita el suyo
-- ---------------------------------------------------------------------
create policy perfil_leer on public.perfil for select using (true);
create policy perfil_editar_propio on public.perfil for update
  using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------------
-- Catálogo del transporte: lectura pública, escritura solo admin.
-- No hay borrado de rutas, paradas ni lugares: se desactivan.
-- ---------------------------------------------------------------------
create policy ruta_leer on public.ruta for select using (activa or public.es_admin());
create policy ruta_crear on public.ruta for insert with check (public.es_admin());
create policy ruta_editar on public.ruta for update using (public.es_admin()) with check (public.es_admin());

create policy recorrido_leer on public.recorrido for select
  using (public.es_admin() or exists (select 1 from public.ruta r where r.id_ruta = recorrido.id_ruta and r.activa));
create policy recorrido_crear on public.recorrido for insert with check (public.es_admin());
create policy recorrido_editar on public.recorrido for update using (public.es_admin()) with check (public.es_admin());
create policy recorrido_borrar on public.recorrido for delete using (public.es_admin());

create policy parada_leer on public.parada for select using (activa or public.es_admin());
create policy parada_crear on public.parada for insert with check (public.es_admin());
create policy parada_editar on public.parada for update using (public.es_admin()) with check (public.es_admin());

create policy recorrido_parada_leer on public.recorrido_parada for select using (true);
create policy recorrido_parada_admin on public.recorrido_parada for all
  using (public.es_admin()) with check (public.es_admin());

create policy franja_leer on public.franja_servicio for select using (true);
create policy franja_admin on public.franja_servicio for all
  using (public.es_admin()) with check (public.es_admin());

create policy lugar_leer on public.lugar for select using (activo or public.es_admin());
create policy lugar_crear on public.lugar for insert with check (public.es_admin());
create policy lugar_editar on public.lugar for update using (public.es_admin()) with check (public.es_admin());

create policy horario_lugar_leer on public.horario_lugar for select using (true);
create policy horario_lugar_admin on public.horario_lugar for all
  using (public.es_admin()) with check (public.es_admin());

create policy aviso_leer on public.aviso_servicio for select using (true);
create policy aviso_crear on public.aviso_servicio for insert with check (public.es_admin());
create policy aviso_editar on public.aviso_servicio for update using (public.es_admin()) with check (public.es_admin());

create policy aviso_parada_leer on public.aviso_parada for select using (true);
create policy aviso_parada_admin on public.aviso_parada for all
  using (public.es_admin()) with check (public.es_admin());

create policy dia_especial_leer on public.dia_especial for select using (true);
create policy dia_especial_admin on public.dia_especial for all
  using (public.es_admin()) with check (public.es_admin());

-- ---------------------------------------------------------------------
-- Datos personales: cada usuario solo ve y cambia lo suyo
-- ---------------------------------------------------------------------
create policy dispositivo_propio on public.dispositivo for all
  using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());

create policy favorito_propio on public.favorito for all
  using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());

create policy viaje_propio on public.viaje_guardado for all
  using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());

-- Máximo 10 viajes guardados por usuario
create or replace function public.limitar_viajes()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if (select count(*) from public.viaje_guardado where id_usuario = new.id_usuario) >= 10 then
    raise exception 'LIMITE: Puedes guardar hasta 10 viajes';
  end if;
  return new;
end;
$$;
create trigger viaje_limite before insert on public.viaje_guardado
  for each row execute function public.limitar_viajes();

-- ---------------------------------------------------------------------
-- Tablón
-- ---------------------------------------------------------------------
create policy publicacion_leer on public.publicacion for select
  using (estado = 'visible' or id_usuario = auth.uid() or public.es_admin());
create policy publicacion_crear on public.publicacion for insert
  with check (auth.uid() is not null and public.puede_publicar());
create policy publicacion_borrar_propia on public.publicacion for delete
  using (id_usuario = auth.uid() or public.es_admin());
create policy publicacion_moderar on public.publicacion for update
  using (public.es_admin()) with check (public.es_admin());

create policy comentario_leer on public.comentario for select
  using (estado = 'visible' or id_usuario = auth.uid() or public.es_admin());
create policy comentario_crear on public.comentario for insert
  with check (auth.uid() is not null and public.puede_publicar());
create policy comentario_borrar_propio on public.comentario for delete
  using (id_usuario = auth.uid() or public.es_admin());
create policy comentario_moderar on public.comentario for update
  using (public.es_admin()) with check (public.es_admin());

create policy voto_leer on public.voto_util for select using (true);
create policy voto_dar on public.voto_util for insert
  with check (id_usuario = auth.uid() and public.puede_publicar());
create policy voto_quitar on public.voto_util for delete using (id_usuario = auth.uid());

create policy denuncia_leer on public.denuncia for select
  using (id_usuario = auth.uid() or public.es_admin());
create policy denuncia_crear on public.denuncia for insert
  with check (auth.uid() is not null and public.puede_publicar());

create policy bitacora_leer on public.bitacora_admin for select using (public.es_admin());

-- ---------------------------------------------------------------------
-- Almacenamiento: fotos de las unidades (lectura pública, escritura admin)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('unidades', 'unidades', true)
on conflict (id) do nothing;

create policy unidades_leer on storage.objects for select
  using (bucket_id = 'unidades');
create policy unidades_subir on storage.objects for insert
  with check (bucket_id = 'unidades' and public.es_admin());
create policy unidades_cambiar on storage.objects for update
  using (bucket_id = 'unidades' and public.es_admin());
create policy unidades_borrar on storage.objects for delete
  using (bucket_id = 'unidades' and public.es_admin());

-- ---------------------------------------------------------------------
-- Tiempo real: la app abierta recibe los cambios sin recargar
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table
  public.aviso_servicio, public.ruta, public.franja_servicio, public.publicacion;
