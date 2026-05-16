# FCD App (Flutter)

Aplicación mobile-first de **Fraternidad del Círculo Dorado**, construida en Flutter y orientada a iPhone, iPad y teléfonos/tabletas Android.

## Tabla de contenido

- [Estado actual](#estado-actual-mayo-2026)
- [Stack principal](#stack-principal)
- [Funcionalidades implementadas](#funcionalidades-implementadas)
- [Navegación principal](#navegación-principal)
- [Backend y configuración](#backend-y-configuración)
- [Requisitos](#requisitos)
- [Instalación y ejecución](#instalación-y-ejecución)
- [Comandos útiles](#comandos-útiles)
- [Calidad y pruebas](#calidad-y-pruebas)
- [Estructura principal](#estructura-principal)
- [Documentación adicional](#documentación-adicional)
- [Limitaciones actuales](#limitaciones-actuales)
- [Licencia](#licencia)

## Estado actual (mayo 2026)

El proyecto está en operación con autenticación real, consumo de backend productivo, cursos/lecciones, reproducción multimedia, descargas locales, favoritos por usuario, asistente IA, registro y cuenta.

## Stack principal

- **Flutter + Dart** (`^3.11.4`).
- **Dio** para HTTP, descargas y refresh de tokens.
- **Provider + ChangeNotifier** para estado global de sesión.
- **FlutterSecureStorage** para credenciales (tokens y contraseña).
- **local_auth** para autenticación biométrica o del dispositivo.
- **better_player_plus / just_audio** para video y audio.
- **webview_flutter** para documentos (Google Docs Viewer).
- **shared_preferences** para favoritos y progreso local.

## Funcionalidades implementadas

### Sesión, registro y autenticación

- Login real contra backend (`POST /login`).
- Registro de usuarios (`POST /user`) desde la app.
- Restauración de sesión con refresh token (`POST /refresh`).
- Bootstrap de sesión al iniciar (`SessionController.bootstrap`).
- Logout y limpieza de sesión persistida.
- Quick-login con biometría o autenticación del dispositivo.
- Manejo automático de refresh de token en `ApiClient` ante 401/403.

### Cursos y aprendizaje

- Listado de cursos del usuario (`GET /course/MyCourses/{userId}`).
- Catálogo general (`GET /course/All/0`) con búsqueda por texto y filtros por categoría.
- Detalle de curso (`GET /course/0/{courseId}`).
- Carga de temario del curso con límite alto para evitar truncamientos (`GET /lesson/course-lessons/{courseId}/{maxLessons}`).
- Marcado de lección completada y lectura de progreso:
  - `POST /lesson/setLessonUserStatus`
  - `GET /lesson/getCompletedLessonsByUser/{userId}/{courseId}`

### Reproductor de lecciones

- Video con `better_player_plus` (controles avanzados y caché).
- Audio con `just_audio`.
- Documentos con `WebView` + visor de Google Docs.
- Navegación lección a lección y continuidad de progreso.
- Persistencia de posición multimedia para retomar contenido.

### IA

- Carga de prompts por categoría (`GET /prompts`).
- Historial de conversaciones (`GET /chats/{userId}`).
- Persistencia de mensajes (`POST /chats/{chatId}/messages`).
- Respuesta de asistente (`POST /chatAI/chatBot`).
- Control de acceso por plan o trial:
  - `GET /ai-plan/user-check?user_id=...`
  - `POST /ai-trial/check`

### Favoritos y descargas

- Favoritos de lecciones persistidos localmente por usuario (`FavoritesStorage`).
- Descarga de recursos al dispositivo (`DownloadRepository`).
- Historial local de descargas con limpieza de archivos faltantes.
- Apertura de archivos descargados dentro de la app.

### Cuenta

- Vista de datos del usuario.
- Validación de acceso a IA.
- Logout.

## Navegación principal

La app autenticada vive en `HomeShell` y expone 6 secciones:

- Mis Cursos
- Catálogo
- IA
- Favoritos
- Descargas
- Cuenta

Comportamiento adaptativo:

- **Móvil**: `NavigationBar` inferior.
- **Tablet** (`shortestSide >= 600`): `NavigationRail` lateral.

## Backend y configuración

Base URL por defecto:

- `https://circulo-dorado.org:6007/api`

Se puede sobreescribir con `--dart-define`:

```bash
flutter run --dart-define=FCD_API_BASE_URL=https://tu-backend/api
```

## Requisitos

### Requisitos mínimos del sistema (ejecución)

- Android 5.0 (API 21) o superior.
- iOS/iPadOS 13.0 o superior.
- CPU ARM de 64 bits.
- 2 GB de RAM (4 GB recomendado).
- 300 MB de almacenamiento libre, más espacio adicional para descargas.
- Conexión a internet para autenticación y contenido en streaming.

### Requisitos de desarrollo

- Flutter stable (compatible con `Dart ^3.11.4`).
- Android Studio / Xcode para build nativo.
- Dispositivo físico o emulador con conexión a internet.

## Instalación y ejecución

Instalar dependencias:

```bash
flutter pub get
```

Ejecutar en dispositivo conectado:

```bash
flutter run
```

## Comandos útiles

Generar APK o App Bundle:

```bash
flutter build apk
flutter build appbundle
```

Generar build iOS (requiere Xcode):

```bash
flutter build ipa
```

Actualizar íconos (usa `assets/images/logo.jpg`):

```bash
flutter pub run flutter_launcher_icons
```

## Calidad y pruebas

```bash
flutter analyze
flutter test --no-test-assets
```

## Estructura principal

- `lib/main.dart`: bootstrap inicial y provider raíz.
- `lib/src/app.dart`: gate de splash/login/home.
- `lib/src/state/session_controller.dart`: estado global de sesión.
- `lib/src/core`: cliente HTTP, configuración, storage, tema y utilidades.
- `lib/src/features/auth`: login, biometría y registro.
- `lib/src/features/courses`: cursos, resumen y reproductor.
- `lib/src/features/catalog`: catálogo completo y filtros.
- `lib/src/features/ai`: chat IA y validación de acceso.
- `lib/src/features/favorites`: vista y apertura de lecciones favoritas.
- `lib/src/features/downloads`: descargas e historial local.
- `lib/src/features/account`: datos de usuario y cierre de sesión.
- `lib/src/features/home`: shell de navegación adaptativa.

## Documentación adicional

- `docs/fcd_flutter_code_walkthrough.md`: guía detallada del código.
- `docs/fcd_flutter_code_walkthrough.pdf`: versión PDF.

## Limitaciones actuales

- Flujo de recuperación de contraseña no implementado en app.
- El contenido visible depende de permisos/compras del usuario en backend.

## Licencia

Ver [`LICENSE`](LICENSE).
