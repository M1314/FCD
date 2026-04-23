# FCD App (Flutter)

Aplicación mobile-first de **Fraternidad del Círculo Dorado**, construida en Flutter y orientada a iPhone, iPad y tablets Android.

## Estado actual (abril 2026)

El proyecto está en operación con autenticación real, consumo de backend productivo, cursos/lecciones, reproducción multimedia, descargas locales, favoritos por usuario, asistente IA y cuenta.

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

## Funcionalidades implementadas

### Sesión y autenticación

- Login real contra backend (`POST /login`).
- Restauración de sesión con refresh token (`POST /refresh`).
- Bootstrap de sesión al iniciar (`SessionController.bootstrap`).
- Logout y limpieza de sesión persistida.
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
- Agrupación del historial por curso/lección cuando se dispone de metadata.

## Backend

Base URL por defecto:

- `https://circulo-dorado.org:6007/api`

Se puede sobreescribir con `--dart-define` (ver sección Configuración).

## Requisitos

- Flutter stable (compatible con `Dart ^3.11.4`)
- Dart SDK `^3.11.4`

## Configuración

Instalar dependencias:

```bash
flutter pub get
```

Ejecutar contra un backend distinto:

```bash
flutter run --dart-define=FCD_API_BASE_URL=https://tu-backend/api
```

## Ejecución

```bash
flutter run
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
- `lib/src/features/auth`: login y ciclo de autenticación.
- `lib/src/features/courses`: cursos, resumen y reproductor.
- `lib/src/features/catalog`: catálogo completo y filtros.
- `lib/src/features/ai`: chat IA y validación de acceso.
- `lib/src/features/favorites`: vista y apertura de lecciones favoritas.
- `lib/src/features/downloads`: descargas e historial local.
- `lib/src/features/account`: datos de usuario y cierre de sesión.
- `lib/src/features/home`: shell de navegación adaptativa.

## Documentación adicional

- `docs/fcd_flutter_code_walkthrough.md`: guía detallada del código (actualizada).
- `docs/fcd_flutter_code_walkthrough.pdf`: versión PDF de la guía detallada.

## Limitaciones actuales

- Flujo de registro/recuperación de contraseña no implementado en app.
- El contenido visible depende de permisos/compras del usuario en backend.
