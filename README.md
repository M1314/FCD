# FCD App (Flutter)

Aplicacion mobile-first en Flutter para Fraternidad del Circulo Dorado.

## Lo que incluye esta base

- Login real contra el backend existente.
- Restauracion de sesion con refresh token.
- Navegacion mobile-first por tabs:
  - Cursos
  - IA
  - Descargas
- Splash screen visual personalizado.
- Cursos del usuario y detalle de curso.
- Reproductor de lecciones con:
  - Video (Better Player Plus con configuracion de buffer/cache)
  - Audio (Just Audio)
  - Documentos (WebView con visor Google Docs)
- Descarga de archivos al dispositivo y listado local de descargas.
- Chat IA con historial por categoria y envio de mensajes al endpoint de IA.

## Backend detectado en el sitio actual

Desde el bundle de `circulo-dorado.org` se detecto el backend principal:

- Base URL: `https://circulo-dorado.org:6007/api`

Endpoints usados en esta app:

- Auth:
  - `POST /login`
  - `POST /refresh`
- Cursos y lecciones:
  - `GET /course/MyCourses/{userId}`
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

## Configuracion

### Requisitos

- Flutter stable (3.41+)
- Dart 3.11+

### Instalar dependencias

```bash
flutter pub get
```

### API base URL por entorno

Por defecto usa:

- `https://circulo-dorado.org:6007/api`

Si quieres otro backend:

```bash
flutter run --dart-define=FCD_API_BASE_URL=https://tu-backend/api
```

## Ejecutar

```bash
flutter run
```

## Calidad

```bash
flutter analyze
flutter test --no-test-assets
```

## Estructura principal

- `lib/main.dart`: bootstrap + provider raiz.
- `lib/src/app.dart`: app shell y gate de splash/login/home.
- `lib/src/core`: tema, cliente HTTP, storage, utilidades.
- `lib/src/features/auth`: login y sesion.
- `lib/src/features/courses`: listado, resumen y reproductor.
- `lib/src/features/ai`: chat IA.
- `lib/src/features/downloads`: historial local de descargas.
- `lib/src/state/session_controller.dart`: estado global de sesion y repositorios.

## Notas de video streaming

Para mejorar la experiencia respecto al sitio web, el reproductor de video usa:

- Buffering configurado para evitar cortes frecuentes.
- Cache local de segmentos de video en Android.
- Controles con velocidad de reproduccion y PiP.

Si el backend entrega HLS (`.m3u8`) o MP4 progresivo, Better Player Plus lo soporta.

## Limitaciones actuales

- El flujo de registro/recuperacion de password no esta en esta primera version.
- No se implemento creacion de chat (`POST /chats`) porque el front web actual carga por categorias predefinidas y guarda mensajes sobre `chatId` fijo.
- El contenido exacto visible depende de permisos y compras del usuario en backend.
