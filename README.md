# Camiones Dolores

**Sistema de Información de Transporte** para el transporte urbano de Dolores Hidalgo, Gto.
Responde con datos verificables: qué camión me lleva, dónde lo tomo, dónde me bajo, cada cuánto pasa y si hoy hay algún cambio.

**Integrantes:** Jesús Omar Méndez Enríquez · Jesua Emmanuel Rico Pacheco

> Para instalar, configurar y publicar todo, sigue **[GUIA.md](GUIA.md)** paso a paso.

## Principios

1. **Dato verificable o nada.** Rutas, paradas y horarios los captura la administración con levantamiento de campo; cada dato tiene fuente y fecha.
2. **Rangos honestos.** No hay GPS en las unidades, así que la app no promete "llega en 5 min": muestra frecuencias ("cada 10–15 min") y tiempos como rango.
3. **La comunidad informa, no decide.** El tablón es comunitario y no altera ningún cálculo.
4. **Lo oficial llega al instante.** Cualquier cambio del administrador se notifica por push en segundos.
5. **Funciona sin cuenta y sin señal.** El catálogo se guarda en el teléfono y el planificador corre localmente.

## Perfiles

| Perfil | Dashboard | Qué puede hacer |
| --- | --- | --- |
| **Visitante** (sin cuenta) | Rutas disponibles | Consultar rutas, paradas, horarios y hora pico; planear viajes; seguir rutas y recibir avisos; leer el tablón |
| **Usuario** | Mapa y rutas cercanas | Todo lo anterior + publicar, comentar y marcar "útil" en el tablón; viajes guardados sincronizados |
| **Administrador** | Panel de administración (también en web) | Rutas, recorridos, horarios, paradas, lugares, avisos, días especiales, moderación, usuarios y bitácora |

El registro ya no permite elegir tipo: toda cuenta nueva es Usuario y solo un administrador asigna el rol de administrador.

## Funciones principales

- Mapa real (OpenStreetMap) con rutas y paradas cercanas.
- **Planificador**: rutas directas o con un transbordo. Como el camión se para donde le hacen la mano, el abordaje es el punto del recorrido más cercano, no solo la parada registrada.
- **Estado del servicio**: en servicio y frecuencia, o "fuera de servicio · inicia 6:00", con calendario de días especiales.
- **Hora pico** = horarios de alta demanda: entradas y salidas de escuelas, cambios de turno y tianguis cerca de la ruta.
- **Avisos de servicio con push** instantáneo a quien sigue la ruta; los cambios de recorrido y horario se avisan solos.
- **Avísame cuando llegue**: seguimiento con el GPS del propio teléfono y alarma 300 m antes de bajar.
- Compartir viaje, último camión, viajes guardados con recordatorio, cómo reconocer el camión (foto y letrero), tarifas preferenciales, comparar contra caminar, "¿qué rutas pasan por aquí?", widget de Android, español e inglés.
- **Tablón comunitario** con comentarios, "útil", denuncias y moderación.

## Arquitectura

```
App Flutter (Android + web)          Supabase (plan gratuito)
 data / domain / presentation  ──▶   PostgreSQL: 20 tablas, RLS, triggers, RPC
 MVVM con ChangeNotifier             Auth · Realtime · Storage
 caché local (sin conexión)          Edge Functions ──▶ Firebase Cloud Messaging
 planificador en el teléfono                         ──▶ OpenRouteService (a pie)
                                                     ──▶ Nominatim (direcciones)
GitHub Actions: mantenimiento diario, respaldo semanal, publicación web (GitHub Pages)
```

```
lib/
  core/          configuración, tema, idioma, geometría, tiempo, validaciones
  domain/        entidades, catálogo, planificador, hora pico
  data/          repositorios (Supabase) y caché local
  servicios/     notificaciones, seguimiento GPS, widget
  presentation/  viewmodels, navegación, widgets y pantallas (acceso, visitante, usuario, comun, admin)
supabase/
  migrations/    esquema, lógica y seguridad (probados en PostgreSQL)
  functions/     enviar-push, ruta-a-pie, geocodificar
  seed.sql       datos de ejemplo
.github/workflows/  mantenimiento, respaldo, web
```

## Ejecutar

```bash
flutter pub get
flutter run --dart-define-from-file=config.json
```

`config.json` (no se sube a GitHub; ver `config.example.json`):

```json
{ "SUPABASE_URL": "https://xxxx.supabase.co", "SUPABASE_ANON_KEY": "..." }
```

## Créditos de datos

Mapa © colaboradores de OpenStreetMap · Rutas a pie: openrouteservice.org · Direcciones: Nominatim.
