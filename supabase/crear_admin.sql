-- Convierte en administrador a una cuenta ya registrada desde la app.
-- 1) Regístrate en la app con tu correo.
-- 2) Cambia el correo de abajo y ejecuta este script en Supabase → SQL Editor.
-- Después, los demás administradores se asignan desde la app (Panel → Usuarios).

select set_config('app.cambio_admin', 'si', false);

update public.perfil
   set rol = 'admin', estado = 'activa'
 where id = (select id from auth.users where email = 'admintest@gmail.com');

select set_config('app.cambio_admin', '', false);

select p.nombre, u.email, p.rol
from public.perfil p join auth.users u on u.id = p.id
where p.rol = 'admin';
