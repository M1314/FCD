import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_progress_banner.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers/fake_api_client.dart';

void main() {
  testWidgets('expanded download banner opens upward', (tester) async {
    final repository = _FakeDownloadRepository();
    final controller = DownloadTaskController(downloadRepository: repository);
    late Future<DownloadTaskResult> pendingDownload;

    await tester.binding.setSurfaceSize(const Size(360, 400));
    addTearDown(() async {
      repository.releasePendingDownload();
      await pendingDownload.timeout(
        const Duration(seconds: 1),
        onTimeout: () =>
            const DownloadTaskResult(status: DownloadTaskStatus.canceled),
      );
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 360,
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => DownloadProgressBanner(
                  controller: controller,
                  expanded: true,
                  onToggle: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    pendingDownload = controller.downloadResource(_resource());
    await tester.runAsync(() async {
      final start = DateTime.now();
      while ((!repository.hasPendingDownload || !controller.hasActiveDownloads) &&
          DateTime.now().difference(start) < const Duration(seconds: 1)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump();
    expect(repository.hasPendingDownload, isTrue);
    expect(controller.hasActiveDownloads, isTrue);

    final labelFinder = find.textContaining('Descargando');
    final itemFinder = find.textContaining('Guía');
    expect(labelFinder, findsOneWidget);
    expect(itemFinder, findsOneWidget);
    expect(
      tester.getTopLeft(itemFinder).dy,
      lessThan(tester.getTopLeft(labelFinder).dy),
    );

    await expectLater(
      find.byType(DownloadProgressBanner),
      matchesGoldenFile(
        'goldens/download_progress_banner_expanded.png',
      ),
    );
  });
}

LessonResource _resource() {
  return const LessonResource(
    type: LessonResourceType.document,
    url: 'https://example.com/files/guide.pdf',
    name: 'Guía',
    order: 1,
  );
}

class _FakeDownloadRepository extends DownloadRepository {
  _FakeDownloadRepository() : super(apiClient: FakeApiClient());
  Completer<void>? _pendingCompleter;

  bool get hasPendingDownload => _pendingCompleter != null;

  @override
  Future<String> getDownloadFilePath(LessonResource resource) async {
    return '/tmp/${resource.name}';
  }

  @override
  Future<File> downloadResource(
    LessonResource resource, {
    required ProgressCallback onProgress,
    CancelToken? cancelToken,
    void Function()? onAlreadyDownloaded,
    String courseName = '',
    String lessonName = '',
  }) async {
    _pendingCompleter = Completer<void>();
    await _pendingCompleter!.future;

    final file = File('/tmp/file.pdf');
    onProgress(1, 1);
    return file;
  }

  void releasePendingDownload() {
    _pendingCompleter?.complete();
  }
}
