import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers/fake_api_client.dart';

void main() {
  group('DownloadTaskController', () {
    test('completes download and resets state', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'download_task_controller_test',
      );
      final repository = _FakeDownloadRepository(
        baseDirectory: tempDir,
        completeWithDelay: false,
      );
      final controller = DownloadTaskController(downloadRepository: repository);

      final result = await controller.downloadResource(_resource());

      expect(result.status, DownloadTaskStatus.completed);
      expect(result.file, isNotNull);
      expect(controller.isDownloading, isFalse);
      expect(controller.progress, 0);

      await tempDir.delete(recursive: true);
    });

    test('returns busy while another download is active', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'download_task_controller_test',
      );
      final repository = _FakeDownloadRepository(
        baseDirectory: tempDir,
        completeWithDelay: true,
      );
      final controller = DownloadTaskController(downloadRepository: repository);

      final firstFuture = controller.downloadResource(_resource());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final secondResult = await controller.downloadResource(_resource());
      repository.releasePendingDownload();
      final firstResult = await firstFuture;

      expect(secondResult.status, DownloadTaskStatus.busy);
      expect(firstResult.status, DownloadTaskStatus.completed);

      await tempDir.delete(recursive: true);
    });
  });
}

LessonResource _resource() {
  return const LessonResource(
    type: LessonResourceType.document,
    url: 'https://example.com/files/guide.pdf',
    name: 'Guia',
    order: 1,
  );
}

class _FakeDownloadRepository extends DownloadRepository {
  _FakeDownloadRepository({
    required this.baseDirectory,
    required this.completeWithDelay,
  }) : super(apiClient: FakeApiClient());

  final Directory baseDirectory;
  final bool completeWithDelay;
  Completer<void>? _pendingCompleter;

  @override
  Future<Directory> getBaseDirectory() async => baseDirectory;

  @override
  Future<File> downloadResource(
    LessonResource resource, {
    required ProgressCallback onProgress,
    CancelToken? cancelToken,
    void Function()? onAlreadyDownloaded,
    String courseName = '',
    String lessonName = '',
  }) async {
    if (completeWithDelay) {
      _pendingCompleter = Completer<void>();
      await _pendingCompleter!.future;
    }

    final folder = Directory('${baseDirectory.path}/downloads');
    await folder.create(recursive: true);
    final file = File('${folder.path}/file.pdf');
    await file.writeAsString('ok');
    onProgress(1, 1);
    return file;
  }

  void releasePendingDownload() {
    _pendingCompleter?.complete();
  }
}
