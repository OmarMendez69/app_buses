-- =====================================================================
-- Migración 2: funciones, triggers y procedimientos (RPC)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------
create or replace function public.es_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.perfil
    where id = auth.uid() and rol = 'admin' and estado = 'activa'
  );
$$;

create or replace function public.puede_publicar()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.perfil where id = auth.uid() and estado = 'activa'
  );
$$;

-- Crea el perfil al registrarse (el nombre viene en los metadatos del registro).
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_nombre text;
begin
  v_nombre := left(coalesce(nullif(trim(new.raw_user_meta_data ->> 'nombre'), ''),
                            split_part(coalesce(new.email, ''), '@', 1)), 100);
  if length(trim(v_nombre)) < 2 then
    v_nombre := 'Usuario';
  end if;
  insert into public.perfil (id, nombre)
  values (new.id, v_nombre)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger al_registrar_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil_nuevo_usuario();

-- Nadie puede cambiarse a sí mismo el rol ni el estado (solo vía admin_actualizar_usuario).
create or replace function public.proteger_campos_perfil()
returns trigger
language plpgsql
as $$
begin
  if (new.rol is distinct from old.rol or new.estado is distinct from old.estado)
     and coalesce(current_setting('app.cambio_admin', true), '') <> 'si' then
    raise exception 'No se puede cambiar el rol o el estado desde aquí';
  end if;
  return new;
end;
$$;

create trigger perfil_protegido
  before update on public.perfil
  for each row execute function public.proteger_campos_perfil();

-- ---------------------------------------------------------------------
-- Bitácora de cambios hechos por administradores
-- ---------------------------------------------------------------------
create or replace function public.registrar_bitacora()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  fila jsonb;
  pk   text;
begin
  if auth.uid() is null or not public.es_admin() then
    return coalesce(new, old);
  end if;
  fila := to_jsonb(coalesce(new, old));
  pk := coalesce(
    fila ->> 'id_ruta', fila ->> 'id_parada', fila ->> 'id_recorrido', fila ->> 'id_lugar',
    fila ->> 'id_aviso', fila ->> 'id_horario', fila ->> 'id_franja', fila ->> 'fecha'
  );
  insert into public.bitacora_admin (id_admin, accion, entidad, id_entidad, detalle)
  values (auth.uid(), lower(tg_op), tg_table_name, pk, fila);
  return coalesce(new, old);
end;
$$;

create trigger bitacora_ruta     after insert or update or delete on public.ruta           for each row execute function public.registrar_bitacora();
create trigger bitacora_parada   after insert or update or delete on public.parada         for each row execute function public.registrar_bitacora();
create trigger bitacora_lugar    after insert or update or delete on public.lugar          for each row execute function public.registrar_bitacora();
create trigger bitacora_horario  after insert or update or delete on public.horario_lugar  for each row execute function public.registrar_bitacora();
create trigger bitacora_aviso    after insert or update or delete on public.aviso_servicio for each row execute function public.registrar_bitacora();
create trigger bitacora_especial after insert or update or delete on public.dia_especial   for each row execute function public.registrar_bitacora();

-- ---------------------------------------------------------------------
-- Avisos automáticos cuando cambia una ruta activa
-- Si ya hay un aviso automático de la misma ruta en los últimos 10 minutos,
-- se actualiza ese en lugar de crear otro (evita 10 notificaciones por una edición).
-- ---------------------------------------------------------------------
create or replace function public.aviso_automatico(p_id_ruta int, p_tipo public.tipo_aviso, p_titulo text, p_detalle text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  existente int;
begin
  if not exists (select 1 from public.ruta where id_ruta = p_id_ruta and activa) then
    return;
  end if;

  select id_aviso into existente
  from public.aviso_servicio
  where id_ruta = p_id_ruta and automatico and creado_en > now() - interval '10 minutes'
  order by creado_en desc
  limit 1;

  if existente is not null then
    update public.aviso_servicio
       set detalle = case when position(p_detalle in detalle) > 0 then detalle else detalle || ' ' || p_detalle end
     where id_aviso = existente;
  else
    insert into public.aviso_servicio (id_ruta, tipo, titulo, detalle, automatico, creado_por, vigente_hasta)
    values (p_id_ruta, p_tipo, left(p_titulo, 80), p_detalle, true, auth.uid(), now() + interval '7 days');
  end if;
end;
$$;

create or replace function public.al_desactivar_ruta()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if old.activa and not new.activa then
    insert into public.aviso_servicio (id_ruta, tipo, titulo, detalle, automatico, creado_por)
    values (new.id_ruta, 'suspension', left('Fuera de servicio: ' || new.nombre, 80),
            'La ruta dejó de operar hasta nuevo aviso.', true, auth.uid());
  end if;
  new.actualizado_en := now();
  return new;
end;
$$;

create trigger ruta_desactivada
  before update on public.ruta
  for each row execute function public.al_desactivar_ruta();

-- ---------------------------------------------------------------------
-- RPC: guardar el recorrido completo (trazado + paradas en orden) en una transacción
-- p_paradas: [{"id_parada": 3, "min_desde_inicio": 0}, ...] en orden
-- ---------------------------------------------------------------------
create or replace function public.guardar_recorrido(p_id_recorrido int, p_trazado jsonb, p_paradas jsonb)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_ruta  int;
  v_prev  int := -1;
  v_min   int;
  v_item  jsonb;
  v_orden int := 0;
  v_ids   int[] := '{}';
begin
  if not public.es_admin() then
    raise exception 'Solo administradores';
  end if;

  select id_ruta into v_ruta from public.recorrido where id_recorrido = p_id_recorrido;
  if v_ruta is null then
    raise exception 'El recorrido no existe';
  end if;

  if jsonb_typeof(p_trazado) <> 'array' or jsonb_array_length(p_trazado) < 2 then
    raise exception 'El trazado necesita al menos 2 puntos';
  end if;

  for v_item in select * from jsonb_array_elements(p_paradas) loop
    v_orden := v_orden + 1;
    if (v_item ->> 'id_parada')::int = any (v_ids) then
      raise exception 'La parada % está repetida en el recorrido', v_item ->> 'id_parada';
    end if;
    v_ids := v_ids || (v_item ->> 'id_parada')::int;
    v_min := (v_item ->> 'min_desde_inicio')::int;
    if v_min is not null then
      if v_min < v_prev then
        raise exception 'Los minutos desde la terminal deben ir en aumento (parada %)', v_orden;
      end if;
      v_prev := v_min;
    end if;
  end loop;

  update public.recorrido set trazado = p_trazado where id_recorrido = p_id_recorrido;
  delete from public.recorrido_parada where id_recorrido = p_id_recorrido;

  insert into public.recorrido_parada (id_recorrido, id_parada, orden, min_desde_inicio)
  select p_id_recorrido, (e ->> 'id_parada')::int, o::smallint, (e ->> 'min_desde_inicio')::smallint
  from jsonb_array_elements(p_paradas) with ordinality as t(e, o);

  update public.ruta set revisada_en = current_date where id_ruta = v_ruta;

  insert into public.bitacora_admin (id_admin, accion, entidad, id_entidad, detalle)
  values (auth.uid(), 'update', 'recorrido', p_id_recorrido::text,
          jsonb_build_object('puntos', jsonb_array_length(p_trazado), 'paradas', p_paradas));

  perform public.aviso_automatico(v_ruta, 'cambio_recorrido',
    'Cambió el recorrido de la ' || (select nombre from public.ruta where id_ruta = v_ruta),
    'Revisa el nuevo recorrido y sus paradas.');
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: guardar todas las franjas de un recorrido y tipo de día
-- p_franjas: [{"hora_inicio":"06:00","hora_fin":"09:00","frecuencia_min":8,"frecuencia_max":12,"fuente":"levantamiento"}]
-- ---------------------------------------------------------------------
create or replace function public.guardar_franjas(p_id_recorrido int, p_tipo_dia public.tipo_dia, p_franjas jsonb)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_ruta int;
begin
  if not public.es_admin() then
    raise exception 'Solo administradores';
  end if;
  select id_ruta into v_ruta from public.recorrido where id_recorrido = p_id_recorrido;
  if v_ruta is null then
    raise exception 'El recorrido no existe';
  end if;

  delete from public.franja_servicio where id_recorrido = p_id_recorrido and tipo_dia = p_tipo_dia;

  insert into public.franja_servicio (id_recorrido, tipo_dia, hora_inicio, hora_fin, frecuencia_min, frecuencia_max, fuente)
  select p_id_recorrido, p_tipo_dia, (e ->> 'hora_inicio')::time, (e ->> 'hora_fin')::time,
         (e ->> 'frecuencia_min')::smallint, (e ->> 'frecuencia_max')::smallint,
         coalesce((e ->> 'fuente')::public.fuente_dato, 'levantamiento')
  from jsonb_array_elements(p_franjas) e;

  update public.ruta set revisada_en = current_date where id_ruta = v_ruta;

  insert into public.bitacora_admin (id_admin, accion, entidad, id_entidad, detalle)
  values (auth.uid(), 'update', 'franja_servicio', p_id_recorrido::text,
          jsonb_build_object('tipo_dia', p_tipo_dia, 'franjas', p_franjas));

  perform public.aviso_automatico(v_ruta, 'cambio_horario',
    'Cambió el horario de la ' || (select nombre from public.ruta where id_ruta = v_ruta),
    'Revisa el nuevo horario de servicio.');
exception
  when exclusion_violation then
    raise exception 'Hay franjas que se empalman en el mismo tipo de día';
end;
$$;

-- Una ruta solo se puede activar con al menos un recorrido de 2+ puntos, 2+ paradas y una franja.
create or replace function public.validar_activacion_ruta()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.activa and (tg_op = 'INSERT' or not old.activa) then
    if not exists (
      select 1
      from public.recorrido r
      where r.id_ruta = new.id_ruta
        and jsonb_array_length(r.trazado) >= 2
        and (select count(*) from public.recorrido_parada rp where rp.id_recorrido = r.id_recorrido) >= 2
        and exists (select 1 from public.franja_servicio f where f.id_recorrido = r.id_recorrido)
    ) then
      raise exception 'Para activar la ruta necesita un recorrido con trazado, al menos 2 paradas y un horario';
    end if;
  end if;
  return new;
end;
$$;

create trigger ruta_activable
  before insert or update of activa on public.ruta
  for each row execute function public.validar_activacion_ruta();

-- ---------------------------------------------------------------------
-- Comunidad: límites, denuncias y moderación
-- ---------------------------------------------------------------------
create or replace function public.limitar_publicaciones()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  new.id_usuario := auth.uid();
  new.estado := 'visible';
  new.creado_en := now();
  if (select count(*) from public.publicacion
      where id_usuario = new.id_usuario and creado_en > now() - interval '1 hour') >= 5 then
    raise exception 'LIMITE: Puedes publicar hasta 5 veces por hora';
  end if;
  if new.id_ruta is not null and exists (
      select 1 from public.publicacion
      where id_usuario = new.id_usuario and id_ruta = new.id_ruta and categoria = new.categoria
        and creado_en > now() - interval '30 minutes') then
    raise exception 'LIMITE: Ya publicaste eso sobre esta ruta hace menos de 30 minutos';
  end if;
  return new;
end;
$$;

create trigger publicacion_limites
  before insert on public.publicacion
  for each row execute function public.limitar_publicaciones();

create or replace function public.limitar_comentarios()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  new.id_usuario := auth.uid();
  new.estado := 'visible';
  new.creado_en := now();
  if (select count(*) from public.comentario
      where id_usuario = new.id_usuario and creado_en > now() - interval '1 hour') >= 20 then
    raise exception 'LIMITE: Puedes comentar hasta 20 veces por hora';
  end if;
  return new;
end;
$$;

create trigger comentario_limites
  before insert on public.comentario
  for each row execute function public.limitar_comentarios();

-- 3 o más denuncias pendientes ocultan el contenido mientras el admin lo revisa.
create or replace function public.al_denunciar()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  new.id_usuario := auth.uid();
  new.estado := 'pendiente';
  new.resuelta_por := null;
  new.resuelta_en := null;
  return new;
end;
$$;

create trigger denuncia_normalizar
  before insert on public.denuncia
  for each row execute function public.al_denunciar();

create or replace function public.ocultar_por_denuncias()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.id_publicacion is not null and (
      select count(*) from public.denuncia
      where id_publicacion = new.id_publicacion and estado = 'pendiente') >= 3 then
    update public.publicacion set estado = 'oculto' where id_publicacion = new.id_publicacion;
  end if;
  if new.id_comentario is not null and (
      select count(*) from public.denuncia
      where id_comentario = new.id_comentario and estado = 'pendiente') >= 3 then
    update public.comentario set estado = 'oculto' where id_comentario = new.id_comentario;
  end if;
  return new;
end;
$$;

create trigger denuncia_ocultar
  after insert on public.denuncia
  for each row execute function public.ocultar_por_denuncias();

-- RPC: el admin resuelve todas las denuncias pendientes de un contenido.
create or replace function public.resolver_denuncia(p_id_denuncia int, p_procede boolean)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  d public.denuncia;
begin
  if not public.es_admin() then
    raise exception 'Solo administradores';
  end if;
  select * into d from public.denuncia where id_denuncia = p_id_denuncia;
  if d is null then
    raise exception 'La denuncia no existe';
  end if;

  update public.denuncia
     set estado = case when p_procede then 'procedente' else 'improcedente' end::public.estado_denuncia,
         resuelta_por = auth.uid(),
         resuelta_en = now()
   where estado = 'pendiente'
     and ((d.id_publicacion is not null and id_publicacion = d.id_publicacion)
       or (d.id_comentario is not null and id_comentario = d.id_comentario));

  if d.id_publicacion is not null then
    update public.publicacion
       set estado = case when p_procede then 'oculto' else 'visible' end::public.estado_contenido
     where id_publicacion = d.id_publicacion;
  else
    update public.comentario
       set estado = case when p_procede then 'oculto' else 'visible' end::public.estado_contenido
     where id_comentario = d.id_comentario;
  end if;

  insert into public.bitacora_admin (id_admin, accion, entidad, id_entidad, detalle)
  values (auth.uid(), 'moderar', case when d.id_publicacion is not null then 'publicacion' else 'comentario' end,
          coalesce(d.id_publicacion, d.id_comentario)::text, jsonb_build_object('procede', p_procede));
end;
$$;

-- ---------------------------------------------------------------------
-- Administración de usuarios
-- ---------------------------------------------------------------------
create or replace function public.admin_listar_usuarios()
returns table (id uuid, nombre text, correo text, rol public.rol_usuario, estado public.estado_cuenta,
               creado_en timestamptz, publicaciones bigint)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo administradores';
  end if;
  return query
    select p.id, p.nombre::text, u.email::text, p.rol, p.estado, p.creado_en,
           (select count(*) from public.publicacion x where x.id_usuario = p.id)
    from public.perfil p
    join auth.users u on u.id = p.id
    order by p.creado_en desc;
end;
$$;

create or replace function public.admin_actualizar_usuario(p_id uuid, p_rol public.rol_usuario, p_estado public.estado_cuenta)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo administradores';
  end if;
  if p_id = auth.uid() and (p_rol <> 'admin' or p_estado <> 'activa') then
    raise exception 'No puedes quitarte el rol de administrador ni suspenderte a ti mismo';
  end if;
  perform set_config('app.cambio_admin', 'si', true);
  update public.perfil set rol = p_rol, estado = p_estado where id = p_id;
  perform set_config('app.cambio_admin', '', true);
  insert into public.bitacora_admin (id_admin, accion, entidad, id_entidad, detalle)
  values (auth.uid(), 'update', 'perfil', p_id::text, jsonb_build_object('rol', p_rol, 'estado', p_estado));
end;
$$;

create or replace function public.metricas_admin()
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo administradores';
  end if;
  return jsonb_build_object(
    'usuarios',            (select count(*) from public.perfil),
    'rutas_activas',       (select count(*) from public.ruta where activa),
    'avisos_vigentes',     (select count(*) from public.aviso_servicio
                            where vigente_desde <= now() and (vigente_hasta is null or vigente_hasta > now())),
    'denuncias_pendientes',(select count(*) from public.denuncia where estado = 'pendiente'),
    'publicaciones_7d',    (select count(*) from public.publicacion where creado_en > now() - interval '7 days'),
    'rutas_sin_revisar',   (select count(*) from public.ruta where activa and revisada_en < current_date - 90)
  );
end;
$$;

-- El usuario elimina su cuenta: se borra en Auth y en cascada su perfil;
-- sus publicaciones quedan como "Usuario eliminado" (id_usuario = null).
create or replace function public.eliminar_mi_cuenta()
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sin sesión';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------
-- Vistas
-- ---------------------------------------------------------------------
create or replace view public.v_perfil_resumen
with (security_invoker = true) as
select p.id,
       p.nombre,
       (select count(*) from public.publicacion x where x.id_usuario = p.id and x.estado = 'visible') as publicaciones,
       (select count(*) from public.voto_util v join public.publicacion x on x.id_publicacion = v.id_publicacion
         where x.id_usuario = p.id) as utiles_recibidos
from public.perfil p;
