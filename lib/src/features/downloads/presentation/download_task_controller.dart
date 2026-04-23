import 'dart:io';

import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:flutter/foundation.dart';

enum DownloadTaskStatus { completed, alreadyDownloaded, failed, busy }

class DownloadTaskResult {
  const DownloadTaskResult({required this.status, this.file, this.error});

  final DownloadTaskStatus status;
  final File? file;
  final Object? error;
}

class DownloadTaskController extends ChangeNotifier {
  static const String _defaultResourceName = 'Archivo';

  DownloadTaskController({required DownloadRepository downloadRepository})
    : _downloadRepository = downloadRepository;

  final DownloadRepository _downloadRepository;

  bool _isDownloading = false;
  double _progress = 0;
  String _resourceName = '';

  bool get isDownloading => _isDownloading;
  double get progress => _progress;
  String get resourceName => _resourceName;

  Future<DownloadTaskResult> downloadResource(
    LessonResource resource, {
    String courseName = '',
    String lessonName = '',
  }) async {
    if (_isDownloading) {
      return const DownloadTaskResult(status: DownloadTaskStatus.busy);
    }

    _isDownloading = true;
    _progress = 0;
    _resourceName = resource.name.trim().isEmpty
        ? _defaultResourceName
        : resource.name;
    notifyListeners();

    try {
      var alreadyDownloaded = false;
      final file = await _downloadRepository.downloadResource(
        resource,
        courseName: courseName,
        lessonName: lessonName,
        onAlreadyDownloaded: () {
          alreadyDownloaded = true;
        },
        onProgress: (received, total) {
          if (total <= 0) {
            return;
          }
          final raw = received / total;
          if (!raw.isFinite) {
            return;
          }
          _progress = raw.clamp(0.0, 1.0);
          notifyListeners();
        },
      );

      return DownloadTaskResult(
        status: alreadyDownloaded
            ? DownloadTaskStatus.alreadyDownloaded
            : DownloadTaskStatus.completed,
        file: file,
      );
    } catch (error) {
      return DownloadTaskResult(
        status: DownloadTaskStatus.failed,
        error: error,
      );
    } finally {
      _isDownloading = false;
      _progress = 0;
      notifyListeners();
    }
  }
}
