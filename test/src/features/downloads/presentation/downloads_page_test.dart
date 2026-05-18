import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:fcd_app/src/features/downloads/presentation/downloads_page.dart';
import 'package:fcd_app/src/state/audio_playback_controller.dart';
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

  group('DownloadsPage', () {
    testWidgets('shows refresh indicator when empty', (tester) async {
      final session = SessionController.forTesting(apiClient: FakeApiClient());
      final repository = _FakeDownloadRepository();
      final downloadController = DownloadTaskController(
        downloadRepository: repository,
      );
      final playbackController =
          _TestAudioPlaybackController(hasMiniPlayer: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider<AudioPlaybackController>.value(
              value: playbackController,
            ),
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

    testWidgets('adds extra bottom padding when mini player is visible',
        (tester) async {
      final session = SessionController.forTesting(apiClient: FakeApiClient());
      final repository = _FakeDownloadRepository(
        files: <DownloadedFile>[buildFile()],
      );
      final downloadController = DownloadTaskController(
        downloadRepository: repository,
      );
      final playbackController =
          _TestAudioPlaybackController(hasMiniPlayer: true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider<AudioPlaybackController>.value(
              value: playbackController,
            ),
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

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(
        listView.padding,
        const EdgeInsets.fromLTRB(14, 10, 14, 86),
      );
    });
  });
}

class _FakeDownloadRepository extends DownloadRepository {
  _FakeDownloadRepository({this.files = const []})
      : super(apiClient: FakeApiClient());

  final List<DownloadedFile> files;

  @override
  Future<DownloadCleanupResult> removeMissingDownloads() async {
    return DownloadCleanupResult(removed: 0, files: files);
  }
}

class _TestAudioPlaybackController extends AudioPlaybackController {
  _TestAudioPlaybackController({required this.hasMiniPlayer});

  @override
  final bool hasMiniPlayer;
}
