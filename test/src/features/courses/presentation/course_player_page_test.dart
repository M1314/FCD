import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/courses/presentation/course_player_page.dart';
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
