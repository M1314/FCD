import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloads_page.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../test_helpers/fake_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('DownloadsPage', () {
    testWidgets('shows refresh indicator when empty', (tester) async {
      final session = SessionController.forTesting(apiClient: FakeApiClient());
      final repository = _FakeDownloadRepository();
      final downloadController = DownloadTaskController(
        downloadRepository: repository,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider<DownloadTaskController>.value(
              value: downloadController,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DownloadsPage(downloadRepository: repository),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('Aún no tienes descargas'), findsOneWidget);
    });
  });
}

class _FakeDownloadRepository extends DownloadRepository {
  _FakeDownloadRepository() : super(apiClient: FakeApiClient());

  @override
  Future<DownloadCleanupResult> removeMissingDownloads() async {
    return DownloadCleanupResult(removed: 0, files: <DownloadedFile>[]);
  }
}
