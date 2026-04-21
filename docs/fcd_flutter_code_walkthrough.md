# FCD Flutter App: Beginner-Friendly Code Walkthrough

This document explains the current Flutter codebase step by step for someone who is new to Flutter.

If you are just starting, read this in order from top to bottom.

---

## 1) What this app is

This is a mobile-first Flutter app for Circulo Dorado.

Main features implemented:

- Login with backend authentication.
- Session persistence (user stays logged in after reopening app).
- Token refresh flow when access token expires.
- Course browsing and opening a course.
- Course summary page and lesson player page.
- Lesson media playback:
  - Video with Better Player Plus.
  - Audio with just_audio.
  - Documents using WebView + Google Docs viewer URL.
- Download lesson files to the phone.
- In-app list of downloaded files.
- AI chat section with categories and backend integration.
- Custom splash screen and visual theme.

---

## 2) Flutter concepts used in this project

Before looking at files, know these concepts:

### Widgets

In Flutter, everything on screen is a widget.

- `StatelessWidget`: UI that does not hold mutable state.
- `StatefulWidget`: UI with mutable state (`setState`).

### Build method

Every widget has a `build(BuildContext context)` method where UI is described.

### State management with Provider

This app uses `provider` + `ChangeNotifier`:

- `SessionController` stores authentication/session state.
- Widgets listen to it with `context.watch<SessionController>()`.
- Widgets call actions with `context.read<SessionController>()`.

### Async programming

A lot of code uses `Future`, `async`, `await` for network and disk operations.

---

## 3) High-level architecture

The app follows a layered structure:

- `core/`: shared infrastructure (HTTP client, theme, storage, utilities).
- `features/`: business features (auth, courses, AI, downloads).
- `state/`: app-level state controller (`SessionController`).

Inside each feature, you will mostly see:

- `data/models`: typed objects for API data.
- `data/repositories`: classes that call APIs and return models.
- `presentation`: UI pages/widgets.

Data flow example:

1. UI page asks repository for data.
2. Repository calls `ApiClient`.
3. API response is parsed into models.
4. UI shows models.

---

## 4) App startup flow

### File: `lib/main.dart`

What it does:

1. Calls `WidgetsFlutterBinding.ensureInitialized()`.
2. Creates `SessionController`.
3. Calls `sessionController.bootstrap()` to restore existing session.
4. Wraps app with `ChangeNotifierProvider`.
5. Runs `FcdApp`.

Why this matters:

- Session is checked before user reaches main screens.

### File: `lib/src/app.dart`

Contains:

- `FcdApp`: root `MaterialApp` with theme.
- `_BootstrapGate`: decides which screen to show:
  - Splash (`SplashPage`) while startup is running.
  - Home (`HomeShell`) when authenticated.
  - Login (`LoginPage`) when not authenticated.

It also uses `AnimatedSwitcher` for smooth page transitions.

---

## 5) Global session state

### File: `lib/src/state/session_controller.dart`

This is the core app state object.

Key responsibilities:

- Track session status with enum:
  - `checking`
  - `unauthenticated`
  - `authenticated`
- Hold current `AuthUser`.
- Expose repositories:
  - `courseRepository`
  - `aiChatRepository`
- Handle login/logout/bootstrap.

Important methods:

- `bootstrap()`
  - Called at startup.
  - Tries to restore session via `AuthRepository.restoreSession()`.
- `login(email, password)`
  - Calls `AuthRepository.login`.
  - On success updates state.
- `logout()`
  - Clears storage and memory session.

Token lifecycle hooks:

- `onTokenRefreshed`: stores new access token.
- `onUnauthorized`: forces logout when refresh fails.

---

## 6) Network layer

### File: `lib/src/core/http/api_client.dart`

This wraps Dio and centralizes all HTTP behavior.

Base setup:

- Base URL from `ApiConfig.baseUrl`.
- JSON content type.
- Timeout configuration.

Main HTTP methods:

- `get`
- `post`
- `postWithHeaders`
- `put`
- `delete`
- `download`

Authentication behavior:

- Stores `_accessToken` and `_refreshToken` in memory.
- Adds `Authorization: Bearer ...` header when `authenticated = true`.

Auto refresh behavior (important):

1. If request fails with 401/403, interceptor catches error.
2. If it is not the refresh endpoint and not already retried:
   - calls `_tryRefreshToken()`.
3. If refresh works:
   - retries original request once.
4. If refresh fails:
   - triggers `onUnauthorized` callback.

Error mapping:

- Converts Dio errors into `AppException` with user-friendly messages.

---

## 7) App configuration and shared utilities

### File: `lib/src/core/config/api_config.dart`

- Default API URL: `https://circulo-dorado.org:6007/api`.
- Can be overridden with Dart define: `FCD_API_BASE_URL`.
- Also stores Google Docs viewer prefix.

### File: `lib/src/core/storage/app_storage.dart`

Handles SharedPreferences operations for session fields:

- Access token, refresh token.
- User id, user name, user email, user type.

### File: `lib/src/core/utils/json_utils.dart`

A helper toolbox for defensive parsing of backend data:

- `asMap`, `asList`
- `readString`, `readInt`, `readDouble`, `readBool`
- `decodeJsonArray`

Why useful:

- Backend payloads can be inconsistent in key names and types.
- These functions reduce parsing crashes.

### File: `lib/src/core/theme/app_theme.dart`

Defines app design system:

- Core colors (bronze/gold/deepBrown/etc).
- Text styles with Google Fonts.
- Input fields, buttons, cards, chip theme.

### File: `lib/src/core/widgets/network_image_tile.dart`

Reusable image component:

- Displays network image with rounded corners.
- Shows fallback icon/container when URL is empty or image fails.

---

## 8) Authentication feature

### Models

#### `lib/src/features/auth/data/models/auth_user.dart`

Represents authenticated user fields:

- id, name, email, type
- phone, lastName
- membersChat, shipping addresses JSON

Has two factories:

- `fromLoginResponse`
- `fromRefreshResponse`

These parse slightly different payload structures.

#### `lib/src/features/auth/data/models/auth_session.dart`

Small object that bundles:

- `AuthUser`
- `accessToken`
- `refreshToken`

### Repository

#### `lib/src/features/auth/data/repositories/auth_repository.dart`

Responsibilities:

- `login`: POST `/login`, parse tokens and user, persist session.
- `restoreSession`: POST `/refresh` with refresh token.
- `logout`: clear tokens from memory and storage.

### UI

#### `lib/src/features/auth/presentation/login_page.dart`

Beginner notes:

- Uses `TextEditingController` for email/password fields.
- Uses `Form` + validators.
- Calls `SessionController.login()` on submit.
- Shows loading spinner on button while submitting.
- Shows session error text/snackbar on failure.

---

## 9) Home shell/navigation

### File: `lib/src/features/home/presentation/home_shell.dart`

This is the logged-in container screen.

It has a bottom navigation bar with 3 tabs:

- Courses
- IA
- Downloads

Important detail:

- Uses `IndexedStack` so each tab keeps its state when you switch tabs.

Also provides logout from app bar.

---

## 10) Courses feature

### Data models

#### `lib/src/features/courses/data/models/course.dart`

Represents a course card/details object:

- id, name, subtitle, description
- icon/banner URLs
- pricing fields
- lessons count and max lessons

#### `lib/src/features/courses/data/models/lesson_resource.dart`

Represents one lesson resource item:

- type (`document`, `audio`, `video`)
- url
- name
- order

#### `lib/src/features/courses/data/models/course_lesson.dart`

Represents one lesson and its resources.

It parses resource JSON arrays and merges them into a sorted list.

Convenience getters:

- `documents`
- `videos`
- `audios`

### Repository

#### `lib/src/features/courses/data/repositories/course_repository.dart`

Main API calls:

- `getMyCourses(userId)`
- `getCourse(courseId)`
- `getLessonsByCourse(courseId, maxLessons)`
- `markLessonAsCompleted(...)`
- `getCompletedLessonIds(...)`

### Presentation pages

#### `lib/src/features/courses/presentation/courses_page.dart`

Shows list of user courses.

Flow:

1. On init, loads courses from backend.
2. Handles loading/error/empty states.
3. On tap course:
   - fetches lessons
   - opens `CourseSummaryPage`.

#### `lib/src/features/courses/presentation/course_summary_page.dart`

Shows summary before entering player:

- banner/title/subtitle/description
- counts (lessons/docs/videos/audios)
- temario list
- button “Comenzar curso”

Then navigates to `CoursePlayerPage`.

#### `lib/src/features/courses/presentation/course_player_page.dart`

This is the most complex screen in the app.

Key responsibilities:

- Track current lesson and selected resource.
- Show progress bar based on completed lessons.
- Mark lesson as completed.
- Move to previous/next lesson.
- Render selected resource as:
  - video player
  - audio player
  - document web viewer
- Download current resource.

Media setup details:

- Video:
  - `BetterPlayerController`
  - buffer tuning
  - cache enabled
  - playback controls (speed/skips/pip)
- Audio:
  - `AudioPlayer` from just_audio
  - custom widget with play/pause and seek slider
- Document:
  - `WebViewController`
  - opens Google Docs embedded viewer URL

Download flow:

1. Calls `DownloadRepository.downloadResource(...)`.
2. Updates progress UI during download.
3. Opens file locally with `OpenFilex.open`.

---

## 11) Downloads feature

### Model

#### `lib/src/features/downloads/data/models/downloaded_file.dart`

Represents a downloaded file in local history:

- id, url, name, type
- localPath
- downloadedAt

Includes JSON serialize/deserialize helpers.

### Repository

#### `lib/src/features/downloads/data/repositories/download_repository.dart`

Responsibilities:

- Determine app download folder.
- Download files using `ApiClient.download`.
- Build safe local filename.
- Save local download history in SharedPreferences.
- Read and clear download history.

### UI

#### `lib/src/features/downloads/presentation/downloads_page.dart`

Shows local download history list.

User can:

- pull to refresh
- open file
- clear history

If local file was deleted externally, UI shows a warning message.

---

## 12) AI feature

### Model

#### `lib/src/features/ai/data/models/chat_message.dart`

Simple message entity:

- sender
- content
- timestamp (optional)

Convenience bools: `isUser`, `isBot`.

### Repository

#### `lib/src/features/ai/data/repositories/ai_chat_repository.dart`

API operations:

- `getPrompts()`
- `getChatMessages(userId, chatTitle)`
- `saveChatMessage(...)`
- `askAi(...)`
- `hasAiAccess(userId)`

Important access logic:

- checks active plan endpoint first
- falls back to trial endpoint

### UI

#### `lib/src/features/ai/presentation/ai_chat_page.dart`

Main behavior:

- category chips (Sabiduria, Meditacion, etc)
- loads chat history by category
- composer for user input
- sends user message to backend
- sends AI request with prompt + recent history
- appends AI response to chat
- handles no-access state with dedicated view

---

## 13) Splash feature

### File: `lib/src/features/splash/presentation/splash_page.dart`

What happens:

- Animated background gradients and glowing orbs.
- Rotating central emblem.
- App title/subtitle and progress indicator.

Technically:

- `AnimationController`
- `Tween` animations (`_glow`, `_rotation`)
- `AnimatedBuilder`

---

## 14) Error handling strategy

### File: `lib/src/core/errors/app_exception.dart`

`AppException` is a custom exception type with:

- message
- optional statusCode

Repositories throw this when backend says operation failed.

UI catches errors and displays friendly messages.

---

## 15) Why the code is organized this way

This structure is good for growth because:

- UI and network code are separated.
- Parsing is centralized in model/repository layers.
- Session state is global but controlled from one class.
- New features can be added in new `features/...` folders.

---

## 16) Suggested learning path for a new Flutter developer

If you want to learn from this project effectively:

1. Start with `main.dart` and `app.dart`.
2. Understand `SessionController` and Provider usage.
3. Follow one feature end-to-end (e.g., courses):
   - UI page -> repository -> api client -> model.
4. Read `course_player_page.dart` slowly, because it combines many concepts.
5. Practice by adding one small feature:
   - e.g., “favorite course” local toggle.

---

## 17) Common beginner questions answered

### Q: Why so many `if (!mounted) return;` checks?

Because async calls can complete after widget is disposed. This avoids calling `setState` on an unmounted widget.

### Q: Why not call Dio directly from widgets?

Keeping network code in repositories makes UI cleaner and easier to test.

### Q: Why keep tokens both in memory and SharedPreferences?

- Memory: fast access for every request.
- SharedPreferences: persistence across app restarts.

### Q: Why `IndexedStack` in home tabs?

It preserves tab states (scroll positions/input state) instead of rebuilding every tab switch.

---

## 18) End-to-end example: Login to course playback

1. User opens app.
2. `main.dart` creates `SessionController`, calls `bootstrap`.
3. `_BootstrapGate` in `app.dart` shows splash, then login/home.
4. User logs in from `LoginPage`.
5. `SessionController.login` -> `AuthRepository.login` -> `/login`.
6. Tokens/user saved, state becomes authenticated.
7. `HomeShell` appears, default tab is courses.
8. `CoursesPage` loads user courses.
9. User taps a course, lessons are fetched.
10. `CourseSummaryPage` opens.
11. User taps “Comenzar curso”.
12. `CoursePlayerPage` opens and renders first pending lesson resource.

---

## 19) Final notes

You now have a production-style Flutter foundation with:

- clear separation of concerns
- real backend integration
- media playback and downloads
- AI chat flow
- mobile-first UX

If you are new to Flutter, this is an excellent codebase to study because it includes real-world concerns: auth, networking, persistence, async UI, and media.
