# Guía paso a paso · Camiones Dolores

Sigue los pasos en orden. Cada uno dice **qué hacer**, **qué comando ejecutar** y **cómo saber que salió bien**.
Si algo falla, copia el error completo y pégalo en el chat.

Tiempo estimado: 2 a 3 horas la primera vez.

---

## 0. APIs y servicios que usa el proyecto (todos gratis, sin tarjeta)

| Servicio | Para qué | Plan gratuito | ¿Necesita cuenta/llave? |
| --- | --- | --- | --- |
| **Supabase** | Base de datos PostgreSQL, cuentas, tiempo real, funciones del servidor, fotos | 0.5 GB de base, 1 GB de archivos, 50,000 usuarios al mes. Se pausa si pasa 7 días sin uso (lo evitamos en el paso 7) | Sí: cuenta en supabase.com |
| **Firebase Cloud Messaging** | Notificaciones push | Sin costo | Sí: cuenta de Google |
| **OpenStreetMap** | Mapa (teselas) | Uso moderado con atribución | No |
| **Nominatim** | Buscar direcciones | 1 consulta por segundo (la app la cachea) | No (solo un correo de contacto) |
| **OpenRouteService** | Caminata real por calles | 2,000 rutas al día | Sí: llave gratis |
| **GitHub** | Código, mantenimiento automático, respaldos, página web del admin, descarga del APK | Gratis en repositorio público | Sí |

Nada de esto pide tarjeta de crédito.

---

## 1. Instalar las herramientas

Haz esto una sola vez en tu computadora.

### 1.1 Git
- Windows: descarga de https://git-scm.com/download/win e instala con las opciones por defecto.
- Comprueba en una terminal nueva:
  ```bash
  git --version
  ```

### 1.2 Node.js (lo usamos para las herramientas de Supabase y Firebase)
- Descarga la versión **LTS** de https://nodejs.org e instala.
- Comprueba:
  ```bash
  node --version
  npm --version
  ```

### 1.3 Flutter y Android
Ya lo tienes porque corriste la app en tu Galaxy A55. Solo verifica:
```bash
flutter --version
flutter doctor
```
`flutter doctor` debe salir con palomitas en **Flutter** y **Android toolchain**. Si sale "Android licenses not accepted":
```bash
flutter doctor --android-licenses
```

### 1.4 Firebase CLI y FlutterFire CLI (para las notificaciones)
```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```
Comprueba:
```bash
firebase --version
flutterfire --version
```
> Si `flutterfire` no se reconoce en Windows, agrega `%LOCALAPPDATA%\Pub\Cache\bin` a la variable PATH y abre otra terminal.

La CLI de Supabase **no se instala**: la usamos con `npx supabase ...` (viene con Node).

---

## 2. Poner el código nuevo en tu repositorio

1. Haz un respaldo de tu proyecto actual (copia la carpeta o crea una rama):
   ```bash
   cd app_buses
   git checkout -b version-anterior
   git push -u origin version-anterior
   git checkout main
   ```
2. Borra el contenido de la carpeta (menos la carpeta oculta `.git`) y descomprime ahí el zip nuevo.
3. Descarga las dependencias:
   ```bash
   flutter pub get
   ```
   **Bien si:** termina con `Got dependencies!`.
   **Si falla** por versiones, pega el error en el chat.

---

## 3. Sacar las llaves de las APIs

### 3.1 Supabase
1. Entra a https://supabase.com → **Start your project** → inicia sesión con GitHub.
2. **New project**:
   - Name: `camiones-dolores`
   - Database password: genera una y **guárdala** (la necesitas en el paso 7).
   - Region: la más cercana a México (por ejemplo, *West US* o *East US*).
3. Espera 1 a 2 minutos a que se cree.
4. Anota estos datos (botón **Connect** arriba, o **Project Settings → API Keys**):
   - **Project URL**: `https://xxxxxxxx.supabase.co`
   - **anon key** (o **publishable key**, la que empieza con `sb_publishable_`). Cualquiera de las dos sirve.
   - **Project ref**: las letras de la URL (`xxxxxxxx`).

### 3.2 OpenRouteService
1. Entra a https://openrouteservice.org → **Sign up** (crea la cuenta y confirma tu correo).
2. En tu panel, sección **API Keys / Tokens** → crea una llave (plan *Standard*, gratis).
3. Guárdala: la usas en el paso 6.

### 3.3 Firebase
1. Entra a https://console.firebase.google.com → **Crear proyecto** → nombre `camiones-dolores` → puedes desactivar Google Analytics.
2. No agregues apps a mano: lo hace `flutterfire` en el paso 6.

---

## 4. Base de datos

### 4.1 Crear las tablas, reglas y permisos
Desde la carpeta del proyecto:
```bash
npx supabase login
npx supabase link --project-ref TU_PROJECT_REF
npx supabase db push
```
- `login` abre el navegador para autorizar.
- `link` te pide la contraseña de la base de datos (la del paso 3.1).
- `db push` aplica los 3 archivos de `supabase/migrations`.

**Bien si:** dice `Finished supabase db push`. En el panel de Supabase → **Table Editor** debes ver 20 tablas (`ruta`, `parada`, `recorrido`, `publicacion`…).

> **Alternativa sin terminal:** en Supabase → **SQL Editor**, pega y ejecuta en orden el contenido de los 3 archivos de `supabase/migrations`.

### 4.2 Datos de ejemplo (opcional)
En **SQL Editor**, pega y ejecuta `supabase/seed.sql`. Crea una "Ruta de prueba" con 4 paradas para que veas la app funcionando. **Son datos inventados**; después los reemplazas con el levantamiento real desde el panel de administración.

### 4.3 Ajustes de cuentas
En Supabase → **Authentication → Sign In / Providers → Email**:
- Para la demostración te conviene **desactivar "Confirm email"**. El correo gratuito de Supabase tiene un límite muy bajo de envíos por hora y puede bloquear registros.
- Si lo dejas activado, configura en **Authentication → URL Configuration** la *Site URL* con la dirección de la versión web (paso 7.4).

---

## 5. Correr la app con tu base de datos

1. Copia `config.example.json` como `config.json` (en la raíz del proyecto) y pon tus datos:
   ```json
   {
     "SUPABASE_URL": "https://xxxxxxxx.supabase.co",
     "SUPABASE_ANON_KEY": "eyJhbGciOi...  o  sb_publishable_..."
   }
   ```
   `config.json` ya está en `.gitignore`: no se sube a GitHub.
2. Conecta tu Galaxy A55 por USB (con depuración USB activada) y ejecuta:
   ```bash
   flutter run --dart-define-from-file=config.json
   ```
3. **Bien si:** ves el splash, luego el inicio de sesión. Toca **Entrar como visitante** y debe aparecer la "Ruta de prueba" (si cargaste el paso 4.2).

### 5.1 Crear al primer administrador
1. En la app, **Regístrate** con tu correo.
2. Abre `supabase/crear_admin.sql`, cambia `TU_CORREO@ejemplo.com` por tu correo y ejecútalo en **SQL Editor**.
3. Cierra sesión y vuelve a entrar: debe abrir el **Panel de administración**.
4. Los demás administradores los nombras desde la app: **Panel → menú → Usuarios → ⋮ → Hacer administrador**.

---

## 6. Notificaciones push y funciones del servidor

### 6.1 Conectar Firebase a la app
```bash
firebase login
flutterfire configure --project=TU_PROYECTO_FIREBASE --platforms=android
```
- Esto **reemplaza** `lib/firebase_options.dart` y crea `android/app/google-services.json`.
- Si te pregunta por el *package name*, es `mx.dolores.camiones`.
- Revisa que haya agregado el plugin de Google Services en `android/settings.gradle.kts` y `android/app/build.gradle.kts`. Si no lo hizo, agrega:
  - En `android/settings.gradle.kts`, dentro de `plugins { }`:
    ```kotlin
    id("com.google.gms.google-services") version "4.4.2" apply false
    ```
  - En `android/app/build.gradle.kts`, dentro de `plugins { }`:
    ```kotlin
    id("com.google.gms.google-services")
    ```

### 6.2 Llave de servicio de Firebase (para que el servidor mande push)
1. Firebase → ⚙ **Configuración del proyecto → Cuentas de servicio** → **Generar nueva clave privada**.
2. Se descarga un archivo `.json`. **No lo subas a GitHub.**

### 6.3 Guardar los secretos en Supabase
En Supabase → **Edge Functions → Secrets** (o **Project Settings → Edge Functions**), agrega:

| Nombre | Valor |
| --- | --- |
| `FCM_SERVICE_ACCOUNT` | Todo el contenido del `.json` del paso 6.2 (ábrelo con el Bloc de notas, copia todo y pégalo) |
| `ORS_API_KEY` | La llave de OpenRouteService (paso 3.2) |
| `WEBHOOK_SECRET` | Una contraseña larga que inventes (ej. `dolores-2026-xYz9...`). Guárdala para el paso 6.5 |
| `CONTACTO_NOMINATIM` | Tu correo (Nominatim pide identificarse) |

### 6.4 Publicar las funciones
```bash
npx supabase functions deploy
```
Publica `enviar-push`, `ruta-a-pie` y `geocodificar`.
> Si dice que necesita Docker, usa: `npx supabase functions deploy --use-api`

**Bien si:** en Supabase → **Edge Functions** aparecen las 3.

### 6.5 Conectar la base de datos con las notificaciones (Webhooks)
En Supabase → **Database → Webhooks** (o **Integrations → Database Webhooks**) → **Create a new hook**. Crea **dos**:

| Campo | Webhook 1 | Webhook 2 |
| --- | --- | --- |
| Name | `push_avisos` | `push_comentarios` |
| Table | `aviso_servicio` | `comentario` |
| Events | Insert | Insert |
| Type | Supabase Edge Functions | Supabase Edge Functions |
| Function | `enviar-push` | `enviar-push` |
| HTTP Headers | `x-webhook-secret` = tu `WEBHOOK_SECRET` | igual |

### 6.6 Probar
1. Vuelve a correr la app (`flutter run --dart-define-from-file=config.json`) y acepta el permiso de notificaciones.
2. Sigue la "Ruta de prueba" (estrella).
3. Desde otro teléfono o desde la versión web, como admin, publica un aviso de esa ruta con **Notificar** activado.
4. **Bien si:** te llega la notificación en segundos. Si no llega, revisa en Supabase → **Edge Functions → enviar-push → Logs**.

---

## 7. Hosting y mantenimiento durante un año

### 7.1 Subir el código a GitHub
```bash
git add .
git commit -m "Version 1.0: sistema de informacion de transporte"
git push
```
El repositorio debe ser **público** para que GitHub Pages y Actions sean gratis sin límites prácticos.

### 7.2 Secretos de GitHub
En tu repositorio → **Settings → Secrets and variables → Actions → New repository secret**:

| Nombre | Valor |
| --- | --- |
| `SUPABASE_URL` | La Project URL |
| `SUPABASE_ANON_KEY` | La anon/publishable key |
| `SUPABASE_DB_URL` | Supabase → **Connect** → **Session pooler** → copia la URI y cambia `[YOUR-PASSWORD]` por la contraseña de la base |

> Usa la **Session pooler** y no la *Direct connection*: los servidores de GitHub no se conectan por IPv6.

### 7.3 Activar los workflows
En **Actions**, si te pide habilitarlos, acepta. Luego ejecuta cada uno una vez a mano (**Run workflow**):
- **Mantenimiento diario**: consulta la base todos los días para que Supabase no la pause y hace un commit cada lunes para que GitHub no apague los workflows por inactividad. Si Supabase deja de responder, el workflow falla y **GitHub te manda un correo**.
- **Respaldo semanal**: cada domingo exporta la base y la guarda 90 días en *Artifacts*.
- **Publicar web**: compila la versión web y la publica (siguiente paso).

### 7.4 Versión web (para el administrador)
1. Repositorio → **Settings → Pages → Source: GitHub Actions**.
2. Ejecuta **Publicar web**.
3. Queda en `https://TU_USUARIO.github.io/NOMBRE_DEL_REPO/`. Ahí el admin entra con su cuenta y captura recorridos cómodamente.
4. Cada `git push` a `main` vuelve a publicarla sola.

### 7.5 APK para Android
```bash
flutter build apk --release --dart-define-from-file=config.json
```
El archivo queda en `build/app/outputs/flutter-apk/app-release.apk`.
Súbelo a GitHub → **Releases → Draft a new release** → adjunta el APK → **Publish**. Comparte ese enlace (o un QR hacia él) para que la gente lo descargue.

> El APK se firma con la llave de depuración: sirve para instalarlo directo. Publicar en Play Store tiene un costo único y no es necesario para el proyecto.

### 7.6 Lista de revisión para todo el año
- [ ] El workflow **Mantenimiento diario** sale en verde (revisa una vez por semana).
- [ ] Existe al menos un **Respaldo semanal** reciente en *Artifacts*.
- [ ] Si llega un correo de Supabase avisando que pausará el proyecto: entra al panel y ejecuta **Mantenimiento diario** a mano.
- [ ] Revisa en el panel de admin las rutas con más de 90 días sin revisar.
- [ ] Antes de días festivos, agrega el **día especial** y su aviso.

---

## 8. Cargar los datos reales (levantamiento de campo)

Desde el panel de administración (mejor en la versión web):

1. **Paradas**: menú → Paradas → ➕. Marca cada una en el mapa con su referencia.
2. **Ruta**: Panel → **Nueva ruta** → nombre, color, tarifas, letrero, descripción → Guardar → **Subir foto de la unidad**.
3. **Recorrido**: en la ruta → **Agregar ida** (y vuelta, o circuito) → **Trazado y paradas**:
   - **Importar GPX** grabado en el camión con OsmAnd u OpenTracks, o dibuja tocando el mapa.
   - Cambia a modo **Paradas**, toca las paradas en orden (o mantén presionado para crear una nueva ahí) → **Ordenar según el trazado**.
   - Escribe los **minutos medidos desde la terminal** en cada parada → Guardar.
4. **Horario**: en la ruta → **Horario** → franjas por tipo de día con su frecuencia → Guardar (usa "copiar" para no repetir).
5. Activa la ruta (necesita trazado, 2 paradas y horario).
6. **Lugares y sus horarios**: escuelas (entrada y salida por turno), hospital e IMSS (cambios de turno), oficinas, mercado y tianguis. De aquí sale la **Hora pico**.
7. **Días especiales**: festivos y fiestas locales.

---

## 9. Problemas comunes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| La app dice "Falta la configuración de Supabase" | Corriste `flutter run` sin el archivo | Usa `flutter run --dart-define-from-file=config.json` |
| No aparecen rutas | No cargaste datos o la ruta no está activa | Paso 4.2 o activa la ruta en el panel |
| "No tienes permiso para hacer esto" en el panel | Tu cuenta no es admin | Paso 5.1 |
| No llegan notificaciones | Falta un secreto, un webhook o seguir la ruta | Revisa 6.3, 6.5 y los *Logs* de `enviar-push` |
| La caminata sale "aprox." siempre | Falta `ORS_API_KEY` o se agotó el límite diario | Revisa el secreto; la app sigue funcionando con la línea recta |
| Error de Gradle sobre `google-services` | Falta el plugin o el `google-services.json` | Repite 6.1 |
| El registro tarda o no deja entrar | "Confirm email" activado y sin correo | Paso 4.3 |
| Supabase "Project paused" | Más de 7 días sin actividad | Entra al panel → *Restore project*; revisa el workflow del paso 7.3 |
