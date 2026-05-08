import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DownloadedFile', () {
    test('creates with all fields including artwork', () {
      final file = DownloadedFile(
        id: 'audio:https://example.com/audio.mp3',
        url: 'https://example.com/audio.mp3',
        name: 'Meditation',
        type: 'audio',
        localPath: '/path/to/audio.mp3',
        downloadedAt: DateTime(2025, 1, 1),
        courseName: 'Curso de Mindfulness',
        lessonName: 'Sesión 1',
        courseBannerUrl: 'https://example.com/banner.jpg',
        courseIconUrl: 'https://example.com/icon.png',
        localArtworkPath: '/path/to/artwork.jpg',
      );

      expect(file.id, 'audio:https://example.com/audio.mp3');
      expect(file.url, 'https://example.com/audio.mp3');
      expect(file.name, 'Meditation');
      expect(file.type, 'audio');
      expect(file.localPath, '/path/to/audio.mp3');
      expect(file.downloadedAt, DateTime(2025, 1, 1));
      expect(file.courseName, 'Curso de Mindfulness');
      expect(file.lessonName, 'Sesión 1');
      expect(file.courseBannerUrl, 'https://example.com/banner.jpg');
      expect(file.courseIconUrl, 'https://example.com/icon.png');
      expect(file.localArtworkPath, '/path/to/artwork.jpg');
    });

    test('creates with default empty artwork fields', () {
      final file = DownloadedFile(
        id: 'document:https://example.com/doc.pdf',
        url: 'https://example.com/doc.pdf',
        name: 'Guide',
        type: 'document',
        localPath: '/path/to/doc.pdf',
        downloadedAt: DateTime(2025, 1, 1),
      );

      expect(file.courseBannerUrl, isEmpty);
      expect(file.courseIconUrl, isEmpty);
      expect(file.localArtworkPath, isEmpty);
    });

    test('toJson serializes all fields', () {
      final file = DownloadedFile(
        id: 'video:https://example.com/video.mp4',
        url: 'https://example.com/video.mp4',
        name: 'Intro',
        type: 'video',
        localPath: '/path/to/video.mp4',
        downloadedAt: DateTime(2025, 6, 15, 10, 30),
        courseName: 'Curso de Ventas',
        lessonName: 'Lección 1',
        courseBannerUrl: 'https://example.com/banner.jpg',
        courseIconUrl: 'https://example.com/icon.png',
        localArtworkPath: '/path/to/artwork.jpg',
      );

      final json = file.toJson();

      expect(json['id'], 'video:https://example.com/video.mp4');
      expect(json['url'], 'https://example.com/video.mp4');
      expect(json['name'], 'Intro');
      expect(json['type'], 'video');
      expect(json['localPath'], '/path/to/video.mp4');
      expect(json['courseName'], 'Curso de Ventas');
      expect(json['lessonName'], 'Lección 1');
      expect(json['courseBannerUrl'], 'https://example.com/banner.jpg');
      expect(json['courseIconUrl'], 'https://example.com/icon.png');
      expect(json['localArtworkPath'], '/path/to/artwork.jpg');
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'id': 'audio:https://example.com/audio.mp3',
        'url': 'https://example.com/audio.mp3',
        'name': 'Meditation',
        'type': 'audio',
        'localPath': '/path/to/audio.mp3',
        'downloadedAt': '2025-01-01T00:00:00.000',
        'courseName': 'Mindfulness',
        'lessonName': 'Session 1',
        'courseBannerUrl': 'https://example.com/banner.jpg',
        'courseIconUrl': 'https://example.com/icon.png',
        'localArtworkPath': '/path/to/artwork.jpg',
      };

      final file = DownloadedFile.fromJson(json);

      expect(file.id, 'audio:https://example.com/audio.mp3');
      expect(file.name, 'Meditation');
      expect(file.type, 'audio');
      expect(file.courseName, 'Mindfulness');
      expect(file.courseBannerUrl, 'https://example.com/banner.jpg');
      expect(file.courseIconUrl, 'https://example.com/icon.png');
      expect(file.localArtworkPath, '/path/to/artwork.jpg');
    });

    test('fromJson handles missing artwork fields gracefully', () {
      final json = {
        'id': 'doc:https://example.com/doc.pdf',
        'url': 'https://example.com/doc.pdf',
        'name': 'Guide',
        'type': 'document',
        'localPath': '/path/to/doc.pdf',
        'downloadedAt': '2025-01-01T00:00:00.000',
      };

      final file = DownloadedFile.fromJson(json);

      expect(file.courseBannerUrl, isEmpty);
      expect(file.courseIconUrl, isEmpty);
      expect(file.localArtworkPath, isEmpty);
    });

    test('toRawJson roundtrip preserves data', () {
      final original = DownloadedFile(
        id: 'test-id',
        url: 'https://example.com/test.mp3',
        name: 'Test Audio',
        type: 'audio',
        localPath: '/test/path.mp3',
        downloadedAt: DateTime(2025, 3, 15, 14, 30),
        courseName: 'Test Course',
        lessonName: 'Test Lesson',
        courseBannerUrl: 'https://example.com/banner.jpg',
        courseIconUrl: 'https://example.com/icon.png',
        localArtworkPath: '/test/artwork.jpg',
      );

      final restored = DownloadedFile.fromRawJson(original.toRawJson());

      expect(restored.id, original.id);
      expect(restored.url, original.url);
      expect(restored.name, original.name);
      expect(restored.type, original.type);
      expect(restored.localPath, original.localPath);
      expect(restored.courseName, original.courseName);
      expect(restored.lessonName, original.lessonName);
      expect(restored.courseBannerUrl, original.courseBannerUrl);
      expect(restored.courseIconUrl, original.courseIconUrl);
      expect(restored.localArtworkPath, original.localArtworkPath);
    });
  });
}
