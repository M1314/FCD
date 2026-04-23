# FCD Flutter App: guía detallada del código (con claridad y criterio)

Este documento explica **cómo está construido hoy** el proyecto y, más importante, **por qué está organizado así**.

La idea no es solo leer archivos: es entender decisiones, flujos y límites reales del sistema.

---

## 1) Qué resuelve esta app

FCD es una app Flutter mobile-first para consumo de contenido formativo.

Capacidades productivas actuales:

- autenticación real contra backend
- restauración de sesión con refresh token
- cursos del usuario y catálogo general
- reproductor de lecciones (video, audio, documentos)
- progreso de aprendizaje y marcado de lecciones
- favoritos por usuario (persistencia local)
- descargas locales con historial
- asistente IA con historial por categoría y control de acceso
- cuenta y cierre de sesión

---

## 2) Mapa mental rápido del repositorio

- `lib/main.dart`: arranque de app + inyección de `SessionController`.
- `lib/src/app.dart`: `MaterialApp` y gate de navegación inicial.
- `lib/src/state/session_controller.dart`: estado global de autenticación/sesión.
- `lib/src/core`: infraestructura transversal (HTTP, errores, tema, storage, utilidades).
- `lib/src/features/*`: verticales de negocio (auth, courses, catalog, ai, favorites, downloads, account, home, splash).

Una forma simple de entender el diseño:

- **core** = reglas comunes
- **features** = casos de uso visibles para el usuario
- **state** = pegamento global de sesión

---

## 3) Flujo de arranque (startup)

### `lib/main.dart`

Secuencia real:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. crear `SessionController`
3. ejecutar `await sessionController.bootstrap()`
4. inyectar `SessionController` con `ChangeNotifierProvider`
5. renderizar `FcdApp`

### `lib/src/app.dart`

`_BootstrapGate` decide la pantalla activa con dos condiciones:

- splash no terminado (`~2200ms`)
- sesión aún en estado `checking`

Resultado:

- si alguna se cumple: `SplashPage`
- si no y hay sesión autenticada: `HomeShell`
- en otro caso: `LoginPage`

Además usa `AnimatedSwitcher` para transición limpia entre estados.

**Principio útil:** el usuario nunca ve parpadeos entre login/home durante bootstrap.

---

## 4) Estado global de sesión

### `lib/src/state/session_controller.dart`

`SessionController` gobierna:

- estado (`checking`, `unauthenticated`, `authenticated`)
- usuario autenticado (`AuthUser?`)
- mensaje de error de sesión
- acceso a repositorios compartidos (`CourseRepository`, `AiChatRepository`)

Puntos clave:

- `bootstrap()` intenta restaurar sesión desde storage + refresh endpoint.
- `login(...)` cambia a `checking`, intenta autenticar y luego aplica sesión.
- `logout()` limpia estado local y persistido.
- `ApiClient` se instancia con callbacks:
  - `onTokenRefreshed` para persistir access token nuevo.
  - `onUnauthorized` para forzar logout si refresh falla.

**Sabiduría práctica:** centralizar el ciclo de sesión evita inconsistencias entre pantallas.

---

## 5) Red, autenticación y errores

### `lib/src/core/http/api_client.dart`

`ApiClient` encapsula Dio y estandariza:

- base URL (`ApiConfig.baseUrl`)
- headers, timeouts y métodos HTTP (`get/post/put/delete/download`)
- inyección de token bearer en requests autenticados
- interceptor de renovación de token y reintento único de request

Comportamiento crítico:

1. request autenticado falla con 401/403
2. intenta refresh (si no era ya refresh y no se reintentó)
3. si refresh funciona, reintenta request original
4. si refresh falla, dispara `onUnauthorized`

### Errores

- capa de datos lanza `AppException` para fallas de negocio/backend
- UI convierte errores a mensajes de usuario con `userMessageFromError(...)`

**Principio:** nunca exponer excepciones crudas al usuario final.

---

## 6) Configuración y persistencia

### Config

`lib/src/core/config/api_config.dart` define:

- base URL por defecto: `https://circulo-dorado.org:6007/api`
- override con `--dart-define=FCD_API_BASE_URL=...`
- prefijo de Google Docs viewer para documentos

### Storage

- `AppStorage`: tokens y datos de sesión
- `FavoritesStorage`: favoritos por usuario (`favorites_v1_user_{id}`)
- historial de descargas: `download_history_v1` en `SharedPreferences`

**Criterio arquitectónico:** separar storage por responsabilidad reduce acoplamiento y hace pruebas más directas.

---

## 7) Home y navegación adaptativa

### `lib/src/features/home/presentation/home_shell.dart`

`HomeShell` mantiene navegación autenticada con `IndexedStack`.

Secciones actuales:

1. Mis Cursos
2. Catálogo
3. IA
4. Favoritos
5. Descargas
6. Cuenta

Adaptación por tamaño:

- `shortestSide < 600`: `NavigationBar` inferior
- `shortestSide >= 600`: `NavigationRail` lateral

**Detalle importante:** `IndexedStack` conserva estado por tab (scroll, filtros, etc.).

---

## 8) Auth feature

### Modelos

- `AuthUser`: parsea estructuras de login/refresh
- `AuthSession`: agrupa usuario + access token + refresh token

### Repositorio (`AuthRepository`)

- login (`POST /login`)
- restore session (`POST /refresh`)
- logout (limpieza de memoria + storage)

### UI (`LoginPage`)

- formulario validado
- bloqueo de submit durante request
- feedback visible en fallo

---

## 9) Courses feature

### Repositorio (`CourseRepository`)

Operaciones principales:

- `getMyCourses(userId)`
- `getCourses()`
- `getCourse(courseId)`
- `getLessonsByCourse(courseId, maxLessons)`
- `getAllLessonsByCourse(courseId)`
- `markLessonAsCompleted(...)`
- `getCompletedLessonIds(...)`

Nota importante:

- `getAllLessonsByCourse` usa `allLessonsRequestLimit = 999` para evitar truncar temario cuando backend exige límite en ruta.

### UI

- `CoursesPage`: lista de cursos del usuario y acceso a resumen
- `CourseSummaryPage`: contexto del curso antes de iniciar
- `CoursePlayerPage`: playback, progreso, favoritos, descargas y navegación de lecciones

---

## 10) Course Player: la pantalla más crítica

`CoursePlayerPage` concentra varios subsistemas:

- selección de lección/recurso
- render por tipo (`video`, `audio`, `document`)
- continuidad de reproducción
- guardado de avance
- marcado de completado
- toggle de favorito
- descarga de recurso activo

Puntos de robustez implementados:

- control de índices de recurso para evitar desbordes
- invalidación por request-id en preparaciones asíncronas de media
- persistencia de posición solo para el recurso activo correcto

**Sabiduría práctica:** esta pantalla mezcla IO de red, IO local y ciclo de vida de reproductores; cualquier cambio debe probarse con flujo real de usuario.

---

## 11) Catálogo feature

### `CatalogPage`

Responsabilidades:

- carga de cursos globales
- búsqueda por texto
- agrupación/filtro por categoría
- acceso al flujo de resumen/reproducción

Se apoya en `CourseRepository.getCourses()` y modelos defensivos de parseo.

---

## 12) AI feature

### Repositorio (`AiChatRepository`)

- `getPrompts()`
- `getChatMessages(userId, chatTitle)`
- `saveChatMessage(...)`
- `askAi(...)`
- `hasAiAccess(userId)`

Control de acceso:

1. primero valida plan activo (`/ai-plan/user-check`)
2. si no, prueba trial (`/ai-trial/check`)

### UI (`AiChatPage`)

- categorías como contexto de conversación
- historial por categoría
- envío de mensajes con persistencia
- render de estados de acceso/no acceso

---

## 13) Favorites feature

### `FavoritesPage`

Flujo:

1. cargar IDs favoritos locales por usuario
2. obtener cursos del usuario
3. resolver lecciones por curso (`getAllLessonsByCourse`)
4. construir vista agrupada por curso
5. abrir `CoursePlayerPage` directamente en la lección seleccionada

Esto asegura que un favorito no sea solo un ID suelto, sino una entrada navegable al contexto real del curso.

---

## 14) Downloads feature

### `DownloadRepository`

Hace:

- selección de carpeta base por plataforma
- descarga con progreso y cancelación (Dio)
- normalización de nombre de archivo
- persistencia y lectura del historial local
- limpieza de entradas que ya no existen físicamente

### `DownloadsPage`

- refresca historial
- abre archivo local
- permite limpiar historial
- notifica inconsistencias (archivo borrado fuera de la app)

---

## 15) Cuenta y splash

- `AccountPage`: muestra datos de usuario y permite logout.
- `SplashPage`: animación inicial y transición visual de carga.

Estos módulos son pequeños, pero importantes para percepción de calidad y cierre seguro de sesión.

---

## 16) Estrategia de pruebas y calidad

Comandos del repositorio:

```bash
flutter analyze
flutter test --no-test-assets
```

Actualmente hay pruebas unitarias para:

- parseo defensivo de modelos/JSON
- repositorios de cursos e IA (con fakes)
- utilidades de errores
- lógica de descargas y limpieza

**Principio:** priorizar pruebas en capa de datos evita regresiones silenciosas en integraciones con backend.

---

## 17) Convicciones de diseño ("claridad con sabiduría")

1. **Estado de sesión único y explícito**
   - evita condiciones ambiguas entre pantallas.
2. **Repositorios como frontera de IO**
   - la UI no negocia directamente con payloads crudos.
3. **Parseo defensivo**
   - el backend real puede variar; el cliente debe ser resiliente.
4. **Mensajes de error humanos**
   - fallar con contexto, no con ruido técnico.
5. **Navegación que preserva contexto**
   - usar `IndexedStack` para no castigar al usuario al cambiar de tab.
6. **Cambios pequeños en pantallas críticas**
   - especialmente en `CoursePlayerPage`, donde confluyen varios ciclos de vida.

---

## 18) Ruta recomendada para onboarding técnico

Si acabas de entrar al proyecto:

1. `main.dart` y `app.dart`
2. `SessionController`
3. `ApiClient` + `AuthRepository`
4. flujo completo de cursos (`CoursesPage -> Summary -> Player`)
5. `AiChatRepository` y `AiChatPage`
6. `DownloadRepository` y `FavoritesPage`

Al terminar ese recorrido, ya entiendes la mayor parte del sistema productivo.

---

## 19) Cierre

Este código ya cubre preocupaciones reales de una app de producción: autenticación, renovación de token, persistencia, multimedia, descargas, IA y UX adaptativa.

El siguiente nivel de madurez no es “más código”, sino mantener tres hábitos:

- precisión en contratos de datos,
- pruebas en puntos de riesgo,
- cambios incrementales en módulos críticos.

Ahí está la claridad. Y también la sabiduría técnica.
