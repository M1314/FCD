# FCD

Aplicación Flutter mobile-first para la Fraternidad del Círculo Dorado.

## Objetivo

- Conectar con el backend del sitio `www.circulo-dorado.org` para listar clases.
- Reproducir contenido de video/audio con priorización de buffering para playback más fluido.
- Descargar video/audio para acceso offline.
- Programar recordatorios de práctica.
- Registrar progreso con snippets diarios.
- Mantener scaffolding de escritorio (panel lateral en pantallas grandes).

## Estructura principal

- `lib/main.dart`: UI principal mobile-first y scaffold de escritorio.
- `lib/services/circulo_api.dart`: integración backend + fallback local.
- `lib/services/media_download_service.dart`: descarga de audio/video a almacenamiento local.
- `lib/services/progress_service.dart`: persistencia y cálculo de progreso.
- `lib/services/reminder_service.dart`: recordatorios locales.

## Ejecución

```bash
flutter pub get
flutter run
```
