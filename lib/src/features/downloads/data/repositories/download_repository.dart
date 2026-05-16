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
    String courseName = '',
    String lessonName = '',
  }) async {
    final existingFile = await getExistingDownloadedFile(
      resource,
      courseName: courseName,
      lessonName: lessonName,
    );
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

    final artworkUrl = resource.courseIconUrl.isNotEmpty
        ? resource.courseIconUrl
        : resource.courseBannerUrl;
    final localArtworkPath = await _downloadArtwork(artworkUrl, baseDir);

    await _saveToHistory(
      DownloadedFile(
        id: _resourceId(resource),
        url: resource.url,
        name: resource.name,
        type: resource.type.name,
        localPath: file.path,
        downloadedAt: DateTime.now(),
        courseName: courseName,
        lessonName: lessonName,
        courseBannerUrl: resource.courseBannerUrl,
        courseIconUrl: resource.courseIconUrl,
        localArtworkPath: localArtworkPath,
      ),
    );

    return file;
  }

  Future<File?> getExistingDownloadedFile(
    LessonResource resource, {
    String courseName = '',
    String lessonName = '',
  }) async {
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

    final file = await _findDownloadedFileOnDisk(resource);
    if (file == null) {
      return null;
    }

    DownloadedFile? existingEntry;
    for (final entry in downloads) {
      if (entry.localPath == file.path) {
        existingEntry = entry;
        break;
      }
    }

    await _saveToHistory(
      DownloadedFile(
        id: _resourceId(resource),
        url: resource.url,
        name: resource.name,
        type: resource.type.name,
        localPath: file.path,
        downloadedAt: existingEntry?.downloadedAt ?? DateTime.now(),
        courseName:
            courseName.isNotEmpty ? courseName : existingEntry?.courseName ?? '',
        lessonName:
            lessonName.isNotEmpty ? lessonName : existingEntry?.lessonName ?? '',
        courseBannerUrl:
            resource.courseBannerUrl.isNotEmpty
                ? resource.courseBannerUrl
                : existingEntry?.courseBannerUrl ?? '',
        courseIconUrl:
            resource.courseIconUrl.isNotEmpty
                ? resource.courseIconUrl
                : existingEntry?.courseIconUrl ?? '',
        localArtworkPath: existingEntry?.localArtworkPath ?? '',
      ),
    );

    return file;
  }

  Future<List<DownloadedFile>> getDownloads() async {
    var files = await _readHistory();
    if (files.isEmpty) {
      files = await _rebuildHistoryFromDisk();
    }
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

    if (existing.isEmpty) {
      final recovered = await _rebuildHistoryFromDisk();
      if (recovered.isNotEmpty) {
        return DownloadCleanupResult(removed: removed, files: recovered);
      }
    }

    return DownloadCleanupResult(removed: removed, files: existing);
  }

  Future<void> clearHistory() async {
    final files = await _readHistory();
    for (final entry in files) {
      final file = File(entry.localPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Ignore failures while cleaning up.
        }
      }
      if (entry.localArtworkPath.isNotEmpty) {
        final artwork = File(entry.localArtworkPath);
        if (await artwork.exists()) {
          try {
            await artwork.delete();
          } catch (_) {
            // Ignore failures while cleaning up.
          }
        }
      }
    }
    final baseDir = await getBaseDirectory();
    final downloadsDir = Directory('${baseDir.path}/downloads');
    if (await downloadsDir.exists()) {
      try {
        await downloadsDir.delete(recursive: true);
      } catch (_) {
        // Ignore failures while cleaning up.
      }
    }
    final artworkDir = Directory('${baseDir.path}/artwork');
    if (await artworkDir.exists()) {
      try {
        await artworkDir.delete(recursive: true);
      } catch (_) {
        // Ignore failures while cleaning up.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_downloadHistoryKey);
  }

  Future<void> deleteDownload(DownloadedFile file) async {
    final localFile = File(file.localPath);
    if (await localFile.exists()) {
      try {
        await localFile.delete();
      } catch (_) {
        // Ignore failures while cleaning up.
      }
    }
    if (file.localArtworkPath.isNotEmpty) {
      final artwork = File(file.localArtworkPath);
      if (await artwork.exists()) {
        try {
          await artwork.delete();
        } catch (_) {
          // Ignore failures while cleaning up.
        }
      }
    }
    final parsed = await _readHistory();
    parsed.removeWhere((entry) => _isSameResourceEntry(entry, file));
    await _setHistory(parsed);
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

  Future<List<DownloadedFile>> _rebuildHistoryFromDisk() async {
    final baseDir = await getBaseDirectory();
    final folder = Directory('${baseDir.path}/downloads');
    if (!await folder.exists()) {
      return <DownloadedFile>[];
    }

    final recovered = <DownloadedFile>[];
    await for (final entity in folder.list()) {
      if (entity is! File) {
        continue;
      }
      final filename = entity.path.split(Platform.pathSeparator).last;
      final parsed = _parseRecoveredEntry(filename);
      final modified = await entity.lastModified();
      recovered.add(
        DownloadedFile(
          id: parsed.id,
          url: parsed.url,
          name: parsed.name,
          type: parsed.type,
          localPath: entity.path,
          downloadedAt: modified,
          localArtworkPath: '',
        ),
      );
    }

    if (recovered.isNotEmpty) {
      await _setHistory(recovered);
    }
    return recovered;
  }

  _RecoveredDownload _parseRecoveredEntry(String filename) {
    final pattern = RegExp(r'^(\d+)_(.+)$');
    final match = pattern.firstMatch(filename);
    var namePart = filename;
    if (match != null && match.groupCount >= 2) {
      namePart = match.group(2) ?? filename;
    }
    final dot = namePart.lastIndexOf('.');
    final ext = dot != -1 ? namePart.substring(dot + 1).toLowerCase() : '';
    var type = 'document';
    if (ext == 'mp3' || ext == 'wav' || ext == 'm4a' || ext == 'aac') {
      type = 'audio';
    } else if (ext == 'mp4' || ext == 'mov' || ext == 'mkv') {
      type = 'video';
    }
    final displayName = dot != -1 ? namePart.substring(0, dot) : namePart;
    return _RecoveredDownload(
      id: 'recovered:${filename.toLowerCase()}',
      url: '',
      name: displayName.replaceAll('_', ' '),
      type: type,
    );
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
    return a.id == b.id ||
        (a.type == b.type && a.url == b.url) ||
        a.localPath == b.localPath;
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

  /// Downloads [artworkUrl] to a local file and returns its path.
  /// Returns an empty string if the URL is empty or download fails.
  Future<String> _downloadArtwork(String artworkUrl, Directory baseDir) async {
    if (artworkUrl.isEmpty) {
      return '';
    }

    try {
      final uri = Uri.tryParse(artworkUrl);
      final uriPath = uri?.path ?? artworkUrl;
      final dot = uriPath.lastIndexOf('.');
      final ext =
          (dot != -1 && dot < uriPath.length - 1 && uriPath.length - dot <= 6)
              ? uriPath.substring(dot)
              : '.jpg';

      final artworkDir = Directory('${baseDir.path}/artwork');
      if (!await artworkDir.exists()) {
        await artworkDir.create(recursive: true);
      }

      final filename = 'artwork_${artworkUrl.hashCode}$ext';
      final artworkFile = File('${artworkDir.path}/$filename');

      if (await artworkFile.exists()) {
        return artworkFile.path;
      }

      await _apiClient.download(artworkUrl, artworkFile.path);
      return artworkFile.path;
    } catch (_) {
      return '';
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

  String _normalizedResourceName(LessonResource resource) {
    final normalized =
        resource.name.trim().isEmpty ? resource.type.name : resource.name.trim();
    return normalized
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  String _resourceFileSuffix(LessonResource resource) {
    final extension = _extensionFromResource(resource);
    final normalized = _normalizedResourceName(resource);
    final normalizedLower = normalized.toLowerCase();
    final filename =
        normalizedLower.endsWith('.$extension')
            ? normalized
            : '$normalized.$extension';
    return '_$filename';
  }

  Future<File?> _findDownloadedFileOnDisk(LessonResource resource) async {
    final baseDir = await getBaseDirectory();
    final folder = Directory('${baseDir.path}/downloads');
    if (!await folder.exists()) {
      return null;
    }

    final suffix = _resourceFileSuffix(resource).toLowerCase();
    File? match;
    DateTime? matchModified;

    await for (final entity in folder.list()) {
      if (entity is! File) {
        continue;
      }
      final filename =
          entity.path.split(Platform.pathSeparator).last.toLowerCase();
      if (!filename.endsWith(suffix)) {
        continue;
      }

      final modified = await entity.lastModified();
      if (match == null || modified.isAfter(matchModified!)) {
        match = entity;
        matchModified = modified;
      }
    }

    return match;
  }
}

class DownloadCleanupResult {
  const DownloadCleanupResult({required this.removed, required this.files});

  final int removed;
  final List<DownloadedFile> files;
}

class _RecoveredDownload {
  const _RecoveredDownload({
    required this.id,
    required this.url,
    required this.name,
    required this.type,
  });

  final String id;
  final String url;
  final String name;
  final String type;
}
