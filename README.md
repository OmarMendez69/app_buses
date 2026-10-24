# Camiones Dolores

## 1. Descripción breve

App móvil hecha en Flutter para consultar las rutas de camiones cercanas, ver su próximo horario y reportar el paso de un camión. Usa datos de ejemplo (mock) y arquitectura por capas (`data` / `domain` / `presentation`) con MVVM.

**Integrantes:** [Tu nombre] · [Nombre de tu compañero]

## 2. Los 3 tipos de usuario y sus dashboards

| Usuario | Dashboard | Qué puede hacer |
|---|---|---|
| **Administrador** | Panel de administración | Gestiona las rutas: **agrega y edita** (nombre, color, frecuencia, activa). Ve métricas (usuarios, rutas activas, reportes) y todos los reportes. |
| **Alumno** | Mapa + rutas cercanas | Busca rutas por destino, ve el próximo camión, reporta el paso de un camión y consulta reportes y su perfil (con reputación). |
| **Visitante** | Rutas disponibles | Consulta las rutas y la hora pico, y puede reportar un camión y ver los reportes. |

Los roles siguen el modelo de dominio del proyecto (tabla `Usuario`): el alumno y el visitante reportan, el admin gestiona rutas.

El dashboard se elige según el rol con el que se inicia sesión o se registra la persona.

## 3. Manejo de estado elegido (y por qué)

**`ChangeNotifier` + `ListenableBuilder` (patrón MVVM, sin paquetes externos).**

- Ya venía en el proyecto (`InicioViewModel`), así que seguimos la misma convención en toda la app.
- Es el manejo de estado que trae Flutter de fábrica: no agrega dependencias y es fácil de explicar.
- Se crea **un solo juego de ViewModels** en `main.dart` (`SesionViewModel`, `InicioViewModel`, `ReportesViewModel`) y se pasa a las pantallas. Por eso el rol, los datos y las listas **persisten al navegar** entre pantallas mientras la app está abierta.
- Para el tamaño de esta entrega (solo vista y validaciones) no se justifica Provider/Riverpod/Bloc.

## 4. Cómo ejecutar la app

Requisitos: Flutter instalado y un emulador o dispositivo conectado.

```bash
git clone <url-del-repo>
cd <carpeta-del-repo>
flutter pub get
flutter run
```

Usuarios de prueba (contraseña `123456`):

| Rol | Correo |
|---|---|
| Administrador | admin@camiones.com |
| Alumno | alumno@camiones.com |
| Visitante | visitante@camiones.com |

También se puede crear una cuenta nueva desde "Regístrate" eligiendo el rol.

## 5. Demostración al docente

- Dispositivo/emulador usado: [Android/iOS · modelo/versión]
- Fecha y modalidad de la demostración: [presencial / videollamada]

## 6. Screenshots

### Splashscreen
![Splash](screenshots/01-splash.png)

### Autenticación
![Login](screenshots/02-login.png)
![Registro](screenshots/03-registro.png)

### Dashboards
![Dashboard Admin](screenshots/04-dashboard-admin.png)
![Dashboard Alumno](screenshots/05-dashboard-cliente.png)
![Dashboard Visitante](screenshots/06-dashboard-operador.png)

### Listas
![Lista principal](screenshots/07-lista-principal.png)
![Lista detalle](screenshots/08-lista-detalle.png)
![Estado vacío](screenshots/09-lista-vacia.png)

### Formularios
![Formulario reporte (alumno / visitante)](screenshots/10-formulario.png)
![Formulario ruta (administrador)](screenshots/13-formulario-ruta.png)

### Evidencia funcional
![Foto equipo](screenshots/11-foto-equipo.png)
![Navegación](screenshots/12-navegacion.png)
