import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LessonResource', () {
    test('copyWithCourseMedia adds course artwork', () {
      const resource = LessonResource(
        type: LessonResourceType.audio,
        url: 'https://example.com/audio.mp3',
        name: 'Meditation',
        order: 1,
      );

      final withArtwork = resource.copyWithCourseMedia(
        courseBannerUrl: 'https://example.com/banner.jpg',
        courseIconUrl: 'https://example.com/icon.png',
      );

      expect(withArtwork.type, LessonResourceType.audio);
      expect(withArtwork.url, 'https://example.com/audio.mp3');
      expect(withArtwork.name, 'Meditation');
      expect(withArtwork.order, 1);
      expect(withArtwork.courseBannerUrl, 'https://example.com/banner.jpg');
      expect(withArtwork.courseIconUrl, 'https://example.com/icon.png');
    });

    test('original resource is unchanged after copyWithCourseMedia', () {
      const resource = LessonResource(
        type: LessonResourceType.video,
        url: 'https://example.com/video.mp4',
        name: 'Introduction',
        order: 2,
      );

      resource.copyWithCourseMedia(
        courseBannerUrl: 'https://example.com/banner.jpg',
        courseIconUrl: 'https://example.com/icon.png',
      );

      expect(resource.courseBannerUrl, isEmpty);
      expect(resource.courseIconUrl, isEmpty);
    });

    test('isAudio returns true for audio type', () {
      const resource = LessonResource(
        type: LessonResourceType.audio,
        url: 'https://example.com/audio.mp3',
        name: 'Test',
        order: 1,
      );

      expect(resource.isAudio, isTrue);
      expect(resource.isVideo, isFalse);
      expect(resource.isDocument, isFalse);
    });

    test('isVideo returns true for video type', () {
      const resource = LessonResource(
        type: LessonResourceType.video,
        url: 'https://example.com/video.mp4',
        name: 'Test',
        order: 1,
      );

      expect(resource.isVideo, isTrue);
      expect(resource.isAudio, isFalse);
      expect(resource.isDocument, isFalse);
    });

    test('isDocument returns true for document type', () {
      const resource = LessonResource(
        type: LessonResourceType.document,
        url: 'https://example.com/doc.pdf',
        name: 'Test',
        order: 1,
      );

      expect(resource.isDocument, isTrue);
      expect(resource.isAudio, isFalse);
      expect(resource.isVideo, isFalse);
    });
  });
}
