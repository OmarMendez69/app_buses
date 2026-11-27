-- =====================================================================
-- Datos de EJEMPLO para probar la app.
-- Las coordenadas y horarios NO son reales: reemplázalos con el
-- levantamiento de campo desde el panel de administración.
-- =====================================================================

insert into public.parada (nombre, referencia, latitud, longitud) values
  ('Ejemplo · Jardín',      'Punto de prueba en el centro',  21.156400, -100.934300),
  ('Ejemplo · Mercado',     'Punto de prueba 2',             21.159200, -100.930100),
  ('Ejemplo · Av. Norte',   'Punto de prueba 3',             21.164800, -100.926900),
  ('Ejemplo · Terminal N',  'Punto de prueba 4 (terminal)',  21.170100, -100.923800);

insert into public.ruta (nombre, color, tarifa, letrero, descripcion_unidad, concesionario, activa)
values ('Ruta de prueba', '#E53935', 12.00, 'CENTRO - NORTE', 'Unidad blanca con franja roja (ejemplo)', 'Ejemplo', false);

insert into public.recorrido (id_ruta, sentido, trazado)
select id_ruta, 'ida', '[[-100.9343,21.1564],[-100.9321,21.1578],[-100.9301,21.1592],[-100.9285,21.1620],[-100.9269,21.1648],[-100.9252,21.1675],[-100.9238,21.1701]]'::jsonb
from public.ruta where nombre = 'Ruta de prueba';

insert into public.recorrido_parada (id_recorrido, id_parada, orden, min_desde_inicio)
select r.id_recorrido, p.id_parada, x.orden, x.minutos
from public.recorrido r
join public.ruta ru on ru.id_ruta = r.id_ruta and ru.nombre = 'Ruta de prueba'
join (values ('Ejemplo · Jardín', 1, 0), ('Ejemplo · Mercado', 2, 4),
             ('Ejemplo · Av. Norte', 3, 9), ('Ejemplo · Terminal N', 4, 14)) as x(nombre, orden, minutos)
  on true
join public.parada p on p.nombre = x.nombre;

insert into public.franja_servicio (id_recorrido, tipo_dia, hora_inicio, hora_fin, frecuencia_min, frecuencia_max)
select r.id_recorrido, f.tipo_dia::public.tipo_dia, f.ini::time, f.fin::time, f.fmin, f.fmax
from public.recorrido r
join public.ruta ru on ru.id_ruta = r.id_ruta and ru.nombre = 'Ruta de prueba'
join (values ('laborable', '06:00', '09:00', 8, 12),
             ('laborable', '09:00', '21:30', 12, 18),
             ('sabado',    '07:00', '20:00', 15, 20),
             ('domingo_festivo', '08:00', '19:00', 20, 30)) as f(tipo_dia, ini, fin, fmin, fmax)
  on true;

update public.ruta set activa = true where nombre = 'Ruta de prueba';

insert into public.lugar (nombre, categoria, latitud, longitud) values
  ('Ejemplo · Escuela', 'educacion', 21.159800, -100.929500),
  ('Ejemplo · Clínica', 'salud',     21.165100, -100.926000);

insert into public.horario_lugar (id_lugar, tipo_dia, hora, evento, descripcion, fuente)
select l.id_lugar, h.tipo_dia::public.tipo_dia, h.hora::time, h.evento::public.tipo_evento, h.descr, 'institucion'
from public.lugar l
join (values ('Ejemplo · Escuela', 'laborable', '07:00', 'entrada', 'Turno matutino'),
             ('Ejemplo · Escuela', 'laborable', '13:00', 'salida', 'Turno matutino'),
             ('Ejemplo · Clínica', 'laborable', '07:00', 'cambio_turno', null),
             ('Ejemplo · Clínica', 'laborable', '15:00', 'cambio_turno', null)) as h(lugar, tipo_dia, hora, evento, descr)
  on h.lugar = l.nombre;

-- Días festivos oficiales del año de operación (puedes agregar fiestas locales desde el panel)
insert into public.dia_especial (fecha, nombre, tipo_dia_aplicado) values
  ('2026-12-25', 'Navidad', 'domingo_festivo'),
  ('2027-01-01', 'Año Nuevo', 'domingo_festivo'),
  ('2027-09-16', 'Día de la Independencia', 'domingo_festivo'),
  ('2027-12-25', 'Navidad', 'domingo_festivo')
on conflict (fecha) do nothing;
