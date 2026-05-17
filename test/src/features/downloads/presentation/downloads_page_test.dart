import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloads_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DownloadedFile buildFile({String courseName = '', String lessonName = ''}) {
    return DownloadedFile(
      id: '1',
      url: 'https://example.com/resource.pdf',
      name: 'resource.pdf',
      type: 'document',
      localPath: '/tmp/resource.pdf',
      downloadedAt: DateTime(2026, 1, 1),
      courseName: courseName,
      lessonName: lessonName,
      localArtworkPath: '',
    );
  }

  group('downloadsCourseHeadingFor', () {
    test('returns course when present', () {
      final heading = downloadsCourseHeadingFor(
        buildFile(courseName: 'Curso A', lessonName: 'Lección 1'),
      );

      expect(heading, 'Curso A');
    });

    test('returns fallback heading when course is empty', () {
      final heading = downloadsCourseHeadingFor(
        buildFile(lessonName: 'Lección 1'),
      );

      expect(heading, 'Descargas');
    });
  });

  group('downloadsLessonHeadingFor', () {
    test('returns lesson when present', () {
      final heading = downloadsLessonHeadingFor(
        buildFile(courseName: 'Curso A', lessonName: 'Lección 1'),
      );

      expect(heading, 'Lección 1');
    });

    test('returns empty when lesson is missing', () {
      final heading = downloadsLessonHeadingFor(buildFile(courseName: 'Curso A'));

      expect(heading, isEmpty);
    });
  });
}
