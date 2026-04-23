# FCD App (Flutter)

Aplicación mobile-first en Flutter para Fraternidad del Círculo Dorado, con soporte para iPhone y iPad.

## Estado actual

La app ya integra autenticación real, consumo de backend productivo, reproductor multimedia de lecciones, descargas locales, catálogo de cursos, favoritos, asistente IA y sección de cuenta.

### Navegación principal (tabs)

- Mis Cursos
- Catálogo
- IA
- Favoritos
- Descargas
- Cuenta

## Funcionalidades implementadas

- Login real contra backend (`/login`) y restauración de sesión con refresh token (`/refresh`).
- Bootstrap de sesión + pantalla splash animada.
- Listado de cursos del usuario y detalle del curso con resumen previo.
- Catálogo general de cursos (`/course/All/0`) con búsqueda y agrupación por categoría.
- Reproductor de lecciones con:
  - Video (`better_player_plus`, buffer/cache, controles avanzados).
  - Audio (`just_audio`).
  - Documentos (WebView + visor de Google Docs).
- Marcado de lecciones completadas y seguimiento de progreso.
- Favoritos de lecciones persistidos por usuario en local.
- Descarga de recursos al dispositivo + historial local de descargas.
- Chat IA por categorías con historial y verificación de acceso a plan/trial.
- Pantalla de cuenta con datos de usuario, estado de plan IA y cierre de sesión.

## Backend y endpoints usados

Base URL por defecto:

- `https://circulo-dorado.org:6007/api`

Endpoints utilizados:

- Auth:
  - `POST /login`
  - `POST /refresh`
- Cursos y lecciones:
  - `GET /course/MyCourses/{userId}`
  - `GET /course/All/0`
  - `GET /course/0/{courseId}`
  - `GET /lesson/course-lessons/{courseId}/{maxLessons}`
  - `POST /lesson/setLessonUserStatus`
  - `GET /lesson/getCompletedLessonsByUser/{userId}/{courseId}`
- IA:
  - `GET /prompts`
  - `GET /chats/{userId}`
  - `POST /chats/{chatId}/messages`
  - `POST /chatAI/chatBot`
  - `GET /ai-plan/user-check?user_id=...`
  - `POST /ai-trial/check`

## Requisitos

- Flutter stable (3.41+)
- Dart 3.11+

## Configuración

Instalar dependencias:

```bash
flutter pub get
```

Cambiar backend por entorno:

```bash
flutter run --dart-define=FCD_API_BASE_URL=https://tu-backend/api
```

## Ejecutar

```bash
flutter run
```

## Calidad y pruebas

```bash
flutter analyze
flutter test --no-test-assets
```

Actualmente hay cobertura de pruebas para parseo defensivo de JSON y modelos clave de cursos/lecciones.

## Estructura principal

- `lib/main.dart`: bootstrap inicial y provider raíz.
- `lib/src/app.dart`: gate de splash/login/home.
- `lib/src/core`: configuración, cliente HTTP, tema, storage y utilidades.
- `lib/src/features/auth`: login y manejo de sesión.
- `lib/src/features/courses`: cursos, resumen y reproductor de lecciones.
- `lib/src/features/catalog`: catálogo completo de cursos.
- `lib/src/features/ai`: chat IA y acceso a plan/trial.
- `lib/src/features/favorites`: lecciones favoritas.
- `lib/src/features/downloads`: descargas e historial local.
- `lib/src/features/account`: información de cuenta y logout.
- `lib/src/state/session_controller.dart`: estado global de sesión y repositorios.

## Documentación adicional

- `docs/fcd_flutter_code_walkthrough.md`: recorrido guiado del código para onboarding técnico.

## Limitaciones actuales

- Flujo de registro/recuperación de contraseña no implementado en app.
- El contenido visible depende de permisos/compras del usuario en backend.
