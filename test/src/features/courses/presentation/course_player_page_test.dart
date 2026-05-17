import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/courses/presentation/course_player_page.dart';
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
}
