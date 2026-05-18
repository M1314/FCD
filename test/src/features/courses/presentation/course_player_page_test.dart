import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/courses/presentation/course_player_page.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldKeepExistingAudioPlayer', () {
    test('keeps audio when opening a document resource', () {
      const document = LessonResource(
        type: LessonResourceType.document,
        url: 'https://example.com/doc.pdf',
        name: 'PDF',
        order: 1,
      );

      expect(
        shouldKeepExistingAudioPlayer(
          nextResource: document,
          hasPreviousAudioPlayer: true,
        ),
        isTrue,
      );
    });

    test('does not keep audio when opening another audio resource', () {
      const audio = LessonResource(
        type: LessonResourceType.audio,
        url: 'https://example.com/audio.mp3',
        name: 'Audio',
        order: 1,
      );

      expect(
        shouldKeepExistingAudioPlayer(
          nextResource: audio,
          hasPreviousAudioPlayer: true,
        ),
        isFalse,
      );
    });

    test('does not keep audio when opening a video resource', () {
      const video = LessonResource(
        type: LessonResourceType.video,
        url: 'https://example.com/video.mp4',
        name: 'Video',
        order: 1,
      );

      expect(
        shouldKeepExistingAudioPlayer(
          nextResource: video,
          hasPreviousAudioPlayer: true,
        ),
        isFalse,
      );
    });
  });

  group('resourceDownloadKeyFor', () {
    test('strips query parameters and fragments from URLs', () {
      const resource = LessonResource(
        type: LessonResourceType.video,
        url: 'https://example.com/video.mp4?token=123#section',
        name: 'Video',
        order: 1,
      );

      expect(
        resourceDownloadKeyFor(resource),
        'video:https://example.com/video.mp4',
      );
    });

    test('keeps URLs without query parameters intact', () {
      const resource = LessonResource(
        type: LessonResourceType.video,
        url: 'https://example.com/video.mp4',
        name: 'Video',
        order: 1,
      );

      expect(
        resourceDownloadKeyFor(resource),
        'video:https://example.com/video.mp4',
      );
    });
  });

  group('downloadedFileForResource', () {
    test('returns match when url has query params stored normalized', () {
      const resource = LessonResource(
        type: LessonResourceType.audio,
        url: 'https://example.com/audio.mp3?token=abc',
        name: 'Audio',
        order: 1,
      );
      final file = DownloadedFile(
        id: 'audio:https://example.com/audio.mp3',
        url: 'https://example.com/audio.mp3?token=abc',
        name: 'Audio',
        type: 'audio',
        localPath: '/tmp/audio.mp3',
        downloadedAt: DateTime(2026, 1, 1),
        localArtworkPath: '',
      );
      final filesByKey = <String, DownloadedFile>{
        'audio:https://example.com/audio.mp3': file,
      };

      final match = downloadedFileForResource(resource, filesByKey);

      expect(match, file);
    });

    test('falls back to raw url key when normalized key is missing', () {
      const resource = LessonResource(
        type: LessonResourceType.video,
        url: 'https://example.com/video.mp4',
        name: 'Video',
        order: 1,
      );
      final file = DownloadedFile(
        id: 'video:https://example.com/video.mp4',
        url: resource.url,
        name: 'Video',
        type: 'video',
        localPath: '/tmp/video.mp4',
        downloadedAt: DateTime(2026, 1, 1),
        localArtworkPath: '',
      );
      final filesByKey = <String, DownloadedFile>{
        'video:${resource.url}': file,
      };

      final match = downloadedFileForResource(resource, filesByKey);

      expect(match, file);
    });

    test('returns null when there is no match', () {
      const resource = LessonResource(
        type: LessonResourceType.document,
        url: 'https://example.com/guide.pdf',
        name: 'Guide',
        order: 1,
      );
      final filesByKey = <String, DownloadedFile>{};

      final match = downloadedFileForResource(resource, filesByKey);

      expect(match, isNull);
    });
  });

  group('coursePlayerScrollBottomPadding', () {
    test('uses base padding when no overlays are visible', () {
      expect(
        coursePlayerScrollBottomPadding(
          showMiniPlayer: false,
          hasDownloads: false,
        ),
        16,
      );
    });

    test('uses mini player padding when mini player is visible', () {
      expect(
        coursePlayerScrollBottomPadding(
          showMiniPlayer: true,
          hasDownloads: false,
        ),
        86,
      );
    });

    test('adds downloads padding when downloads banner is visible', () {
      expect(
        coursePlayerScrollBottomPadding(
          showMiniPlayer: false,
          hasDownloads: true,
        ),
        102,
      );
    });

    test('adds both overlays when mini player and downloads are visible', () {
      expect(
        coursePlayerScrollBottomPadding(
          showMiniPlayer: true,
          hasDownloads: true,
        ),
        172,
      );
    });
  });
  testWidgets('buildTopSnackBar aligns to the top of the screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => buildTopSnackBar(
            context,
            'Archivo descargado.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final align = tester.widget<Align>(find.byType(Align));
    expect(align.alignment, Alignment.topCenter);
    expect(find.text('Archivo descargado.'), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
  });
}
