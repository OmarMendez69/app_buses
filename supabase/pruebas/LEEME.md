# Pruebas de la base de datos

Estas pruebas se corrieron en PostgreSQL 16 local imitando lo que trae Supabase
(`stub_supabase.sql` crea los roles anon/authenticated, `auth.users`, `auth.uid()` y `storage`).

Verifican, entre otras cosas:
- Un visitante (anon) no puede escribir rutas ni publicar.
- Un usuario no puede darse rol de admin ni escribir el catálogo.
- Límite de 5 publicaciones por hora y 1 por ruta+categoría cada 30 min.
- Denuncia duplicada rechazada; 3 denuncias ocultan la publicación; el admin la resuelve.
- Franjas empalmadas rechazadas; minutos desde la terminal deben crecer; paradas repetidas rechazadas.
- Avisos automáticos agrupados (uno por edición, no uno por cambio).
- Una ruta sin recorrido/paradas/horario no se puede activar.
- Desactivar una ruta genera un aviso de suspensión.
- Bitácora de cambios del admin.
- Usuario suspendido no puede publicar; eliminar cuenta deja publicaciones como "Usuario eliminado".
- Paradas fuera del municipio rechazadas.

Cómo correrlas (con PostgreSQL instalado):
```bash
createdb dolores
psql -d dolores -f stub_supabase.sql
for f in ../migrations/*.sql ../seed.sql; do psql -d dolores -v ON_ERROR_STOP=1 -f $f; done
psql -d dolores -f pruebas.sql
```
Los `ERROR` que aparecen son los esperados: cada línea marcada con `-- falla` debe fallar.
