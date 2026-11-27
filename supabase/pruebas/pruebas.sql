\set ON_ERROR_STOP 0
\pset pager off
-- Usuarios: un admin y dos usuarios
insert into auth.users (id, email, raw_user_meta_data) values
 ('11111111-1111-1111-1111-111111111111','admin@x.com','{"nombre":"Admin"}'),
 ('22222222-2222-2222-2222-222222222222','ana@x.com','{"nombre":"Ana"}'),
 ('33333333-3333-3333-3333-333333333333','beto@x.com','{}');
select id, nombre, rol from perfil order by nombre;
\i ../crear_admin.sql
update perfil set rol='admin' where nombre='Admin'; -- debe fallar (protegido)
select set_config('app.cambio_admin','si',false); update perfil set rol='admin' where nombre='Admin'; select set_config('app.cambio_admin','',false);

-- ===== Anónimo
set role anon; select set_config('request.jwt.claims','',false);
select 'anon ve rutas activas' t, count(*) from ruta;
insert into ruta(nombre,color,tarifa) values ('X','#000000',10); -- falla
insert into publicacion(categoria,texto) values ('general','hola'); -- falla
select 'anon cache' t, count(*) from cache_api; -- 0 filas
reset role;

-- ===== Usuario Ana
set role authenticated; select set_config('request.jwt.claims','{"sub":"22222222-2222-2222-2222-222222222222"}',false);
update perfil set nombre='Ana María' where id=auth.uid();
update perfil set rol='admin' where id=auth.uid(); -- falla: sin permiso de columna
insert into ruta(nombre,color,tarifa) values ('X','#000000',10); -- falla RLS
insert into publicacion(categoria,texto,id_ruta) values ('retraso','Va tarde la ruta',1);
insert into publicacion(categoria,texto,id_ruta) values ('retraso','Otra vez tarde',1); -- falla: misma ruta+categoria 30 min
insert into publicacion(categoria,texto) values ('general','uno'),('general','dos'),('general','tres');
insert into publicacion(categoria,texto) values ('general','cinco'); -- 5a OK
insert into publicacion(categoria,texto) values ('general','seis'); -- falla: limite 5/h
select 'pubs ana' t, count(*) from publicacion where id_usuario=auth.uid();
select metricas_admin(); -- falla
insert into favorito(id_usuario,id_ruta) values (auth.uid(),1);
insert into favorito(id_usuario,id_ruta) values ('33333333-3333-3333-3333-333333333333',1); -- falla RLS
reset role;

-- ===== Beto denuncia; 3 denuncias ocultan
set role authenticated; select set_config('request.jwt.claims','{"sub":"33333333-3333-3333-3333-333333333333"}',false);
insert into voto_util select min(id_publicacion), auth.uid() from publicacion;
insert into denuncia(id_publicacion,motivo) select min(id_publicacion),'spam' from publicacion;
insert into denuncia(id_publicacion,motivo) select min(id_publicacion),'spam' from publicacion; -- falla: duplicada
insert into comentario(id_publicacion,texto) select min(id_publicacion),'Gracias' from publicacion;
reset role;
set role authenticated; select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111"}',false);
insert into denuncia(id_publicacion,motivo) select min(id_publicacion),'spam' from publicacion;
reset role;
insert into auth.users (id,email) values ('44444444-4444-4444-4444-444444444444','c@x.com');
set role authenticated; select set_config('request.jwt.claims','{"sub":"44444444-4444-4444-4444-444444444444"}',false);
insert into denuncia(id_publicacion,motivo) values ((select min(id_publicacion) from publicacion where id_usuario='22222222-2222-2222-2222-222222222222'),'ofensivo');
select 'pub 1 vista por otro (debe ser 0, oculta)' t, count(*) from publicacion where id_publicacion=2;
reset role;

-- ===== Admin
set role authenticated; select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111"}',false);
select metricas_admin();
select resolver_denuncia((select min(id_denuncia) from denuncia), false);
select 'pub1 estado' t, estado from publicacion where id_publicacion=2;
select 'denuncias' t, estado, count(*) from denuncia group by estado;
select nombre, correo, rol, publicaciones from admin_listar_usuarios();
select admin_actualizar_usuario('33333333-3333-3333-3333-333333333333','usuario','suspendida');
select admin_actualizar_usuario(auth.uid(),'usuario','activa'); -- falla
-- franjas empalmadas
select guardar_franjas(1,'sabado','[{"hora_inicio":"07:00","hora_fin":"12:00","frecuencia_min":10,"frecuencia_max":15},{"hora_inicio":"11:00","hora_fin":"18:00","frecuencia_min":10,"frecuencia_max":15}]'); -- falla
select guardar_franjas(1,'sabado','[{"hora_inicio":"07:00","hora_fin":"12:00","frecuencia_min":10,"frecuencia_max":15},{"hora_inicio":"12:00","hora_fin":"18:00","frecuencia_min":15,"frecuencia_max":20}]');
select 'franjas sabado' t, count(*) from franja_servicio where tipo_dia='sabado';
-- recorrido con minutos que bajan
select guardar_recorrido(1,'[[-100.93,21.15],[-100.92,21.16]]','[{"id_parada":1,"min_desde_inicio":0},{"id_parada":2,"min_desde_inicio":5},{"id_parada":3,"min_desde_inicio":3}]'); -- falla
select guardar_recorrido(1,'[[-100.93,21.15],[-100.92,21.16]]','[{"id_parada":1,"min_desde_inicio":0},{"id_parada":1,"min_desde_inicio":5}]'); -- falla repetida
select guardar_recorrido(1,(select trazado from recorrido where id_recorrido=1),'[{"id_parada":1,"min_desde_inicio":0},{"id_parada":2,"min_desde_inicio":5},{"id_parada":4,"min_desde_inicio":15}]');
select 'avisos automaticos (debe ser 1 por debounce)' t, count(*) from aviso_servicio where automatico;
select titulo, detalle from aviso_servicio;
-- nueva ruta sin datos no se puede activar
insert into ruta(nombre,color,tarifa) values ('Ruta nueva','#1E88E5',12);
update ruta set activa=true where nombre='Ruta nueva'; -- falla
insert into ruta(nombre,color,tarifa,tarifa_estudiante) values ('Mala','#1E88E5',12,6); -- falla: sin fuente
update ruta set activa=false where nombre='Ruta de prueba';
select 'aviso suspension' t, tipo, titulo from aviso_servicio where tipo='suspension';
select accion, entidad, id_entidad from bitacora_admin order by id;
reset role;

-- ===== Beto suspendido no puede publicar
set role authenticated; select set_config('request.jwt.claims','{"sub":"33333333-3333-3333-3333-333333333333"}',false);
insert into publicacion(categoria,texto) values ('general','hola'); -- falla
select * from v_perfil_resumen order by nombre;
reset role;
-- Eliminar cuenta: Ana
set role authenticated; select set_config('request.jwt.claims','{"sub":"22222222-2222-2222-2222-222222222222"}',false);
select eliminar_mi_cuenta();
reset role;
select 'pubs huerfanas' t, count(*) from publicacion where id_usuario is null;
-- parada fuera del municipio
insert into parada(nombre,latitud,longitud) values ('Lejos', 19.43, -99.13); -- falla
