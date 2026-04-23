import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadRepository {
  DownloadRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  static const String _downloadHistoryKey = 'download_history_v1';

  Future<Directory> getBaseDirectory() async {
    if (Platform.isIOS) {
      return getApplicationDocumentsDirectory();
    }
    return getApplicationSupportDirectory();
  }

  Future<File> downloadResource(
    LessonResource resource, {
    required ProgressCallback onProgress,
    CancelToken? cancelToken,
    void Function()? onAlreadyDownloaded,
  }) async {
    final existingFile = await getExistingDownloadedFile(resource);
    if (existingFile != null) {
      onAlreadyDownloaded?.call();
      return existingFile;
    }

    final baseDir = await getBaseDirectory();
    final folder = Directory('${baseDir.path}/downloads');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final extension = _extensionFromResource(resource);
    final filename = _safeFileName(
      resource.name,
      resource.type.name,
      extension,
    );
    final file = File('${folder.path}/$filename');

    await _apiClient.download(
      resource.url,
      file.path,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );

    await _saveToHistory(
      DownloadedFile(
        id: _resourceId(resource),
        url: resource.url,
        name: resource.name,
        type: resource.type.name,
        localPath: file.path,
        downloadedAt: DateTime.now(),
      ),
    );

    return file;
  }

  Future<File?> getExistingDownloadedFile(LessonResource resource) async {
    final downloads = await getDownloads();
    for (final existing in downloads) {
      if (!_matchesResource(existing, resource)) {
        continue;
      }

      final file = File(existing.localPath);
      if (!await file.exists()) {
        await _removeResourceFromHistory(resource);
        return null;
      }
      return file;
    }
    return null;
  }

  Future<List<DownloadedFile>> getDownloads() async {
    final files = await _readHistory();
    files.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return files;
  }

  Future<DownloadCleanupResult> removeMissingDownloads() async {
    final files = await getDownloads();
    final existing = <DownloadedFile>[];
    for (final file in files) {
      final local = File(file.localPath);
      if (await local.exists()) {
        existing.add(file);
      }
    }

    final removed = files.length - existing.length;
    if (removed > 0) {
      await _setHistory(existing);
    }
    return DownloadCleanupResult(removed: removed, files: existing);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_downloadHistoryKey);
  }

  Future<void> _saveToHistory(DownloadedFile file) async {
    final parsed = await _readHistory();
    parsed.removeWhere((entry) => _isSameResourceEntry(entry, file));
    parsed.insert(0, file);

    await _setHistory(parsed);
  }

  Future<void> _setHistory(List<DownloadedFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _downloadHistoryKey,
      files.map((entry) => entry.toRawJson()).toList(),
    );
  }

  Future<List<DownloadedFile>> _readHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_downloadHistoryKey) ?? <String>[];
    return rawList
        .map((entry) {
          try {
            return DownloadedFile.fromRawJson(entry);
          } catch (_) {
            return null;
          }
        })
        .whereType<DownloadedFile>()
        .toList();
  }

  Future<void> _removeResourceFromHistory(LessonResource resource) async {
    final parsed = await _readHistory();
    parsed.removeWhere((entry) => _matchesResource(entry, resource));
    await _setHistory(parsed);
  }

  bool _matchesResource(DownloadedFile existing, LessonResource resource) {
    final stableId = _resourceId(resource);
    final legacyId = _legacyResourceId(resource);
    return existing.id == stableId ||
        existing.id == legacyId ||
        (existing.type == resource.type.name && existing.url == resource.url);
  }

  bool _isSameResourceEntry(DownloadedFile a, DownloadedFile b) {
    return a.id == b.id || (a.type == b.type && a.url == b.url);
  }

  String _legacyResourceId(LessonResource resource) {
    return '${resource.type.name}:${resource.url.hashCode}';
  }

  String _resourceId(LessonResource resource) {
    return '${resource.type.name}:${resource.url}';
  }

  String _extensionFromResource(LessonResource resource) {
    final uri = Uri.tryParse(resource.url);
    final path = uri?.path ?? resource.url;

    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot < path.length - 1) {
      final extension = path.substring(dot + 1).toLowerCase();
      if (extension.length <= 5) {
        return extension;
      }
    }

    switch (resource.type) {
      case LessonResourceType.audio:
        return 'mp3';
      case LessonResourceType.video:
        return 'mp4';
      case LessonResourceType.document:
        return 'pdf';
    }
  }

  String _safeFileName(String name, String prefix, String extension) {
    final normalized = name.trim().isEmpty ? prefix : name.trim();
    final sanitized = normalized
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');

    final withTime = '${DateTime.now().millisecondsSinceEpoch}_$sanitized';
    if (withTime.toLowerCase().endsWith('.$extension')) {
      return withTime;
    }
    return '$withTime.$extension';
  }
}

class DownloadCleanupResult {
  const DownloadCleanupResult({required this.removed, required this.files});

  final int removed;
  final List<DownloadedFile> files;
}
