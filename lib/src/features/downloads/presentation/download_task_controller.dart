import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:flutter/foundation.dart';

enum DownloadTaskStatus { completed, alreadyDownloaded, failed, busy, canceled }

class DownloadTaskResult {
  const DownloadTaskResult({required this.status, this.file, this.error});

  final DownloadTaskStatus status;
  final File? file;
  final Object? error;
}

class DownloadTaskSnapshot {
  const DownloadTaskSnapshot({
    required this.resourceId,
    required this.resourceName,
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
  });

  final String resourceId;
  final String resourceName;
  final int receivedBytes;
  final int totalBytes;
  final double progress;
}

class _DownloadTaskState {
  _DownloadTaskState({
    required this.resourceId,
    required this.resourceName,
    required this.cancelToken,
    required this.filePath,
  })
      : receivedBytes = 0,
        totalBytes = 0,
        progress = 0;

  final String resourceId;
  final String resourceName;
  final CancelToken cancelToken;
  final String filePath;
  int receivedBytes;
  int totalBytes;
  double progress;

  DownloadTaskSnapshot toSnapshot() {
    return DownloadTaskSnapshot(
      resourceId: resourceId,
      resourceName: resourceName,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
      progress: progress,
    );
  }
}

class DownloadTaskController extends ChangeNotifier {
  static const String _defaultResourceName = 'Archivo';

  DownloadTaskController({required DownloadRepository downloadRepository})
    : _downloadRepository = downloadRepository;

  final DownloadRepository _downloadRepository;

  final Map<String, _DownloadTaskState> _activeDownloads =
      <String, _DownloadTaskState>{};

  bool get hasActiveDownloads => _activeDownloads.isNotEmpty;
  List<DownloadTaskSnapshot> get activeDownloads =>
      _activeDownloads.values.map((entry) => entry.toSnapshot()).toList();

  int get overallReceivedBytes {
    var total = 0;
    for (final entry in _activeDownloads.values) {
      total += entry.receivedBytes;
    }
    return total;
  }

  int get overallTotalBytes {
    var total = 0;
    for (final entry in _activeDownloads.values) {
      total += entry.totalBytes;
    }
    return total;
  }

  double get overallProgress {
    final total = overallTotalBytes;
    if (total <= 0) {
      return 0;
    }
    final raw = overallReceivedBytes / total;
    if (!raw.isFinite) {
      return 0;
    }
    return raw.clamp(0.0, 1.0);
  }

  bool isDownloadingResource(LessonResource resource) {
    return _activeDownloads.containsKey(_resourceId(resource));
  }

  Future<DownloadTaskResult> downloadResource(
    LessonResource resource, {
    String courseName = '',
    String lessonName = '',
  }) async {
    final resourceId = _resourceId(resource);
    if (_activeDownloads.containsKey(resourceId)) {
      return const DownloadTaskResult(status: DownloadTaskStatus.busy);
    }

    final resourceName = resource.name.trim().isEmpty
        ? _defaultResourceName
        : resource.name;
    
    // Get the file path before starting download so we can clean up on cancel
    final filePath = await _downloadRepository.getDownloadFilePath(resource);
    
    _activeDownloads[resourceId] = _DownloadTaskState(
      resourceId: resourceId,
      resourceName: resourceName,
      cancelToken: CancelToken(),
      filePath: filePath,
    );
    notifyListeners();

    try {
      var alreadyDownloaded = false;
      final cancelToken = _activeDownloads[resourceId]?.cancelToken;
      final file = await _downloadRepository.downloadResource(
        resource,
        courseName: courseName,
        lessonName: lessonName,
        cancelToken: cancelToken,
        onAlreadyDownloaded: () {
          alreadyDownloaded = true;
        },
        onProgress: (received, total) {
          final entry = _activeDownloads[resourceId];
          if (entry == null) {
            return;
          }
          final normalizedTotal = total > 0 ? total : 0;
          final normalizedReceived = received < 0 ? 0 : received;
          entry.totalBytes = normalizedTotal;
          entry.receivedBytes = normalizedReceived;
          if (normalizedTotal > 0) {
            final raw = normalizedReceived / normalizedTotal;
            entry.progress = raw.isFinite ? raw.clamp(0.0, 1.0) : 0;
          } else {
            entry.progress = 0;
          }
          notifyListeners();
        },
      );

      return DownloadTaskResult(
        status: alreadyDownloaded
            ? DownloadTaskStatus.alreadyDownloaded
            : DownloadTaskStatus.completed,
        file: file,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        return const DownloadTaskResult(status: DownloadTaskStatus.canceled);
      }
      return DownloadTaskResult(
        status: DownloadTaskStatus.failed,
        error: error,
      );
    } catch (error) {
      return DownloadTaskResult(
        status: DownloadTaskStatus.failed,
        error: error,
      );
    } finally {
      _activeDownloads.remove(resourceId);
      notifyListeners();
    }
  }

  void cancelDownload(String resourceId) {
    final entry = _activeDownloads.remove(resourceId);
    if (entry != null) {
      entry.cancelToken.cancel();
      // Clean up the partial download file asynchronously
      _downloadRepository.deletePartialDownload(entry.filePath);
    }
    notifyListeners();
  }

  String _resourceId(LessonResource resource) {
    return '${resource.type.name}:${resource.url}';
  }
}
