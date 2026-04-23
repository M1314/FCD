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
    );
  }

  group('downloadsGroupHeadingFor', () {
    test('combines course and lesson when both are present', () {
      final heading = downloadsGroupHeadingFor(
        buildFile(courseName: 'Curso A', lessonName: 'Lección 1'),
      );

      expect(heading, 'Curso A · Lección 1');
    });

    test('returns course when lesson is empty', () {
      final heading = downloadsGroupHeadingFor(
        buildFile(courseName: 'Curso A'),
      );

      expect(heading, 'Curso A');
    });

    test('returns fallback heading when both are empty', () {
      final heading = downloadsGroupHeadingFor(buildFile());

      expect(heading, 'Descargas');
    });
  });
}
