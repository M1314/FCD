import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../test_helpers/fake_api_client.dart';

void main() {
  group('DownloadRepository.removeMissingDownloads', () {
    test('removes entries whose local file does not exist', () async {
      final tempDir = await Directory.systemTemp.createTemp('fcd-download-test');
      final existingFile = File('${tempDir.path}/exists.pdf');
      await existingFile.writeAsString('ok');
      final missingPath = '${tempDir.path}/missing.pdf';

      final existing = DownloadedFile(
        id: '1',
        url: 'https://example.com/a.pdf',
        name: 'A',
        type: 'document',
        localPath: existingFile.path,
        downloadedAt: DateTime(2024, 1, 1),
        localArtworkPath: '',
      );
      final missing = DownloadedFile(
        id: '2',
        url: 'https://example.com/b.pdf',
        name: 'B',
        type: 'document',
        localPath: missingPath,
        downloadedAt: DateTime(2024, 1, 2),
        localArtworkPath: '',
      );

      SharedPreferences.setMockInitialValues(<String, Object>{
        'download_history_v1': <String>[
          existing.toRawJson(),
          missing.toRawJson(),
        ],
      });

      final repository = DownloadRepository(apiClient: FakeApiClient());

      final cleanup = await repository.removeMissingDownloads();

      expect(cleanup.removed, 1);
      expect(cleanup.files, hasLength(1));
      expect(cleanup.files.single.id, '1');

      final current = await repository.getDownloads();
      expect(current, hasLength(1));
      expect(current.single.id, '1');

      await tempDir.delete(recursive: true);
    });

    test('returns 0 when all files still exist', () async {
      final tempDir = await Directory.systemTemp.createTemp('fcd-download-test');
      final existingFile = File('${tempDir.path}/exists.pdf');
      await existingFile.writeAsString('ok');

      final existing = DownloadedFile(
        id: '1',
        url: 'https://example.com/a.pdf',
        name: 'A',
        type: 'document',
        localPath: existingFile.path,
        downloadedAt: DateTime(2024, 1, 1),
        localArtworkPath: '',
      );

      SharedPreferences.setMockInitialValues(<String, Object>{
        'download_history_v1': <String>[existing.toRawJson()],
      });

      final repository = DownloadRepository(apiClient: FakeApiClient());

      final cleanup = await repository.removeMissingDownloads();

      expect(cleanup.removed, 0);
      expect(cleanup.files, hasLength(1));
      expect(cleanup.files.single.id, '1');

      final current = await repository.getDownloads();
      expect(current, hasLength(1));
      expect(current.single.id, '1');

      await tempDir.delete(recursive: true);
    });
  });

  group('DownloadRepository.getDownloads – recovery from disk', () {
    late Directory tempDir;
    late _TestDownloadRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp('download_recovery_test');
      repository = _TestDownloadRepository(
        apiClient: FakeApiClient(),
        baseDirectory: tempDir,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns empty list when no prefs and no downloads directory', () async {
      final downloads = await repository.getDownloads();
      expect(downloads, isEmpty);
    });

    test('rebuilds history from disk when prefs are empty', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      await downloadsDir.create(recursive: true);
      final file = File('${downloadsDir.path}/12345_my_lesson.pdf');
      await file.writeAsString('content');

      final downloads = await repository.getDownloads();

      expect(downloads, hasLength(1));
      expect(downloads.first.localPath, file.path);
      expect(downloads.first.name, 'my lesson');
      expect(downloads.first.type, 'document');
      expect(downloads.first.id, 'recovered:12345_my_lesson.pdf');
    });

    test('persists recovered entries back to SharedPreferences', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      await downloadsDir.create(recursive: true);
      await File('${downloadsDir.path}/99_audio_track.mp3').writeAsString('audio');

      await repository.getDownloads();

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('download_history_v1');
      expect(stored, isNotNull);
      expect(stored, hasLength(1));

      final recovered = DownloadedFile.fromRawJson(stored!.first);
      expect(recovered.type, 'audio');
      expect(recovered.name, 'audio track');
    });

    test('detects audio type from mp3 filename', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      await downloadsDir.create(recursive: true);
      await File('${downloadsDir.path}/1_track.mp3').writeAsString('audio');

      final downloads = await repository.getDownloads();
      expect(downloads.single.type, 'audio');
    });

    test('detects audio type from wav filename', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      await downloadsDir.create(recursive: true);
      await File('${downloadsDir.path}/1_track.wav').writeAsString('audio');

      final downloads = await repository.getDownloads();
      expect(downloads.single.type, 'audio');
    });

    test('detects video type from mp4 filename', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      await downloadsDir.create(recursive: true);
      await File('${downloadsDir.path}/1_video.mp4').writeAsString('video');

      final downloads = await repository.getDownloads();
      expect(downloads.single.type, 'video');
    });

    test('detects document type from pdf filename', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      await downloadsDir.create(recursive: true);
      await File('${downloadsDir.path}/1_guide.pdf').writeAsString('doc');

      final downloads = await repository.getDownloads();
      expect(downloads.single.type, 'document');
    });

    test('skips disk rebuild when prefs are non-empty', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      await downloadsDir.create(recursive: true);
      final diskFile = File('${downloadsDir.path}/1_extra.pdf');
      await diskFile.writeAsString('extra');

      final existingFile = File('${tempDir.path}/downloads/kept.pdf');
      await existingFile.create(recursive: true);
      await existingFile.writeAsString('kept');

      final entry = DownloadedFile(
        id: 'doc:https://example.com/kept.pdf',
        url: 'https://example.com/kept.pdf',
        name: 'Kept',
        type: 'document',
        localPath: existingFile.path,
        downloadedAt: DateTime(2024, 6, 1),
        localArtworkPath: '',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('download_history_v1', [entry.toRawJson()]);

      final downloads = await repository.getDownloads();

      // Must only return the prefs entry, not the extra file on disk.
      expect(downloads, hasLength(1));
      expect(downloads.single.id, entry.id);
    });

    test('recovered entries are sorted newest first by file modification time', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      await downloadsDir.create(recursive: true);
      final older = File('${downloadsDir.path}/1_older.pdf');
      final newer = File('${downloadsDir.path}/2_newer.pdf');
      await older.writeAsString('older');
      // Ensure a different modification time by setting it explicitly.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await newer.writeAsString('newer');

      final downloads = await repository.getDownloads();

      expect(downloads, hasLength(2));
      expect(
        downloads.first.downloadedAt
            .isAfter(downloads.last.downloadedAt) ||
        downloads.first.downloadedAt
            .isAtSameMomentAs(downloads.last.downloadedAt),
        isTrue,
      );
    });
  });

  group('DownloadRepository.clearHistory', () {
    late Directory tempDir;
    late _TestDownloadRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp('clear_history_test');
      repository = _TestDownloadRepository(
        apiClient: FakeApiClient(),
        baseDirectory: tempDir,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('deletes individual download files and artwork files', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      final artworkDir = Directory('${tempDir.path}/artwork');
      await downloadsDir.create(recursive: true);
      await artworkDir.create(recursive: true);

      final audioFile = File('${downloadsDir.path}/lesson.mp3');
      await audioFile.writeAsString('audio');
      final artworkFile = File('${artworkDir.path}/cover.jpg');
      await artworkFile.writeAsString('art');

      final entry = DownloadedFile(
        id: 'audio:https://example.com/lesson.mp3',
        url: 'https://example.com/lesson.mp3',
        name: 'Lesson',
        type: 'audio',
        localPath: audioFile.path,
        downloadedAt: DateTime.now(),
        localArtworkPath: artworkFile.path,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('download_history_v1', [entry.toRawJson()]);

      await repository.clearHistory();

      expect(await audioFile.exists(), isFalse);
      expect(await artworkFile.exists(), isFalse);
    });

    test('removes downloads and artwork directories', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      final artworkDir = Directory('${tempDir.path}/artwork');
      await downloadsDir.create(recursive: true);
      await artworkDir.create(recursive: true);
      await File('${downloadsDir.path}/a.pdf').writeAsString('a');
      await File('${artworkDir.path}/img.jpg').writeAsString('img');

      final entry = DownloadedFile(
        id: 'doc:https://example.com/a.pdf',
        url: 'https://example.com/a.pdf',
        name: 'A',
        type: 'document',
        localPath: '${downloadsDir.path}/a.pdf',
        downloadedAt: DateTime.now(),
        localArtworkPath: '${artworkDir.path}/img.jpg',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('download_history_v1', [entry.toRawJson()]);

      await repository.clearHistory();

      expect(await downloadsDir.exists(), isFalse);
      expect(await artworkDir.exists(), isFalse);
    });

    test('clears the download_history_v1 SharedPreferences key', () async {
      final entry = DownloadedFile(
        id: 'doc:https://example.com/b.pdf',
        url: 'https://example.com/b.pdf',
        name: 'B',
        type: 'document',
        localPath: '/nonexistent/b.pdf',
        downloadedAt: DateTime.now(),
        localArtworkPath: '',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('download_history_v1', [entry.toRawJson()]);

      await repository.clearHistory();

      final stored = prefs.getStringList('download_history_v1');
      expect(stored, isNull);
    });

    test('succeeds gracefully when history and directories are already empty', () async {
      await expectLater(repository.clearHistory(), completes);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('download_history_v1');
      expect(stored, isNull);
    });

    test('getDownloads returns empty after clearHistory', () async {
      final downloadsDir = Directory('${tempDir.path}/downloads');
      await downloadsDir.create(recursive: true);
      final audioFile = File('${downloadsDir.path}/lesson.mp3');
      await audioFile.writeAsString('audio');

      final entry = DownloadedFile(
        id: 'audio:https://example.com/lesson.mp3',
        url: 'https://example.com/lesson.mp3',
        name: 'Lesson',
        type: 'audio',
        localPath: audioFile.path,
        downloadedAt: DateTime.now(),
        localArtworkPath: '',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('download_history_v1', [entry.toRawJson()]);

      await repository.clearHistory();

      final downloads = await repository.getDownloads();
      expect(downloads, isEmpty);
    });
  });

  group('DownloadRepository.downloadResource', () {
    late Directory tempDir;
    late _FakeDownloadApiClient apiClient;
    late _TestDownloadRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp('download_repository_test');
      apiClient = _FakeDownloadApiClient();
      repository = _TestDownloadRepository(
        apiClient: apiClient,
        baseDirectory: tempDir,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('downloadResource skips API call when resource is already downloaded', () async {
      final resource = _resource();
      final existingPath = '${tempDir.path}/downloads/existing.pdf';
      final existingFile = File(existingPath);
      await existingFile.create(recursive: true);
      await existingFile.writeAsString('existing');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('download_history_v1', <String>[
        DownloadedFile(
          id: _stableResourceId(resource),
          url: resource.url,
          name: resource.name,
          type: resource.type.name,
          localPath: existingPath,
          downloadedAt: DateTime.now(),
          localArtworkPath: '',
        ).toRawJson(),
      ]);

      var alreadyDownloadedCalled = false;
      var progressCallCount = 0;

      final file = await repository.downloadResource(
        resource,
        onProgress: (received, total) {
          progressCallCount++;
        },
        onAlreadyDownloaded: () {
          alreadyDownloadedCalled = true;
        },
      );

      expect(file.path, existingPath);
      expect(apiClient.downloadCalls, 0);
      expect(alreadyDownloadedCalled, isTrue);
      expect(progressCallCount, 0);
    });

    test('downloadResource downloads and records history when missing', () async {
      final resource = _resource();
      const courseName = 'Curso de Ventas';
      const lessonName = 'Lección 1';

      final file = await repository.downloadResource(
        resource,
        courseName: courseName,
        lessonName: lessonName,
        onProgress: (received, total) {},
      );
      final downloads = await repository.getDownloads();

      expect(apiClient.downloadCalls, 1);
      expect(await file.exists(), isTrue);
      expect(downloads, hasLength(1));
      expect(downloads.first.url, resource.url);
      expect(downloads.first.id, _stableResourceId(resource));
      expect(downloads.first.courseName, courseName);
      expect(downloads.first.lessonName, lessonName);
      expect(downloads.first.courseBannerUrl, isEmpty);
      expect(downloads.first.courseIconUrl, isEmpty);
      // No artwork URL → localArtworkPath stays empty
      expect(downloads.first.localArtworkPath, isEmpty);
    });

    test('downloadResource downloads artwork locally when courseIconUrl is set', () async {
      const iconUrl = 'https://example.com/icon.png';
      final resource = LessonResource(
        type: LessonResourceType.audio,
        url: 'https://example.com/files/lesson.mp3',
        name: 'Lección',
        order: 1,
        courseIconUrl: iconUrl,
      );

      await repository.downloadResource(
        resource,
        onProgress: (received, total) {},
      );
      final downloads = await repository.getDownloads();

      // Two download calls: one for the resource, one for the artwork
      expect(apiClient.downloadCalls, 2);
      expect(downloads.first.localArtworkPath, isNotEmpty);
      expect(await File(downloads.first.localArtworkPath).exists(), isTrue);
    });

    test('downloadResource reuses already-downloaded artwork across different resources', () async {
      const iconUrl = 'https://example.com/icon2.png';
      final resource1 = const LessonResource(
        type: LessonResourceType.audio,
        url: 'https://example.com/files/lesson2.mp3',
        name: 'Lección 2',
        order: 1,
        courseIconUrl: iconUrl,
      );
      final resource2 = const LessonResource(
        type: LessonResourceType.audio,
        url: 'https://example.com/files/lesson3.mp3',
        name: 'Lección 3',
        order: 2,
        courseIconUrl: iconUrl, // same artwork URL
      );

      // First download: 2 calls — resource1 + artwork
      await repository.downloadResource(
        resource1,
        onProgress: (received, total) {},
      );
      expect(apiClient.downloadCalls, 2);

      // Second download with same artwork URL: 1 call — resource2 only, artwork reused
      await repository.downloadResource(
        resource2,
        onProgress: (received, total) {},
      );
      expect(apiClient.downloadCalls, 3);
    });

    test('downloadResource still succeeds even if artwork download fails', () async {
      const iconUrl = 'https://example.com/failing-icon.png';
      final resource = LessonResource(
        type: LessonResourceType.audio,
        url: 'https://example.com/files/lesson3.mp3',
        name: 'Lección 3',
        order: 1,
        courseIconUrl: iconUrl,
      );

      apiClient.failArtworkUrls.add(iconUrl);

      final file = await repository.downloadResource(
        resource,
        onProgress: (received, total) {},
      );
      final downloads = await repository.getDownloads();

      expect(await file.exists(), isTrue);
      expect(downloads.first.localArtworkPath, isEmpty);
    });

    test('downloadResource accepts legacy hash-based ids for existing files', () async {
      final resource = _resource();
      final existingPath = '${tempDir.path}/downloads/existing-legacy.pdf';
      final existingFile = File(existingPath);
      await existingFile.create(recursive: true);
      await existingFile.writeAsString('existing');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('download_history_v1', <String>[
        DownloadedFile(
          id: _legacyResourceId(resource),
          url: resource.url,
          name: resource.name,
          type: resource.type.name,
          localPath: existingPath,
          downloadedAt: DateTime.now(),
          localArtworkPath: '',
        ).toRawJson(),
      ]);

      final file = await repository.downloadResource(
        resource,
        onProgress: (received, total) {},
      );

      expect(file.path, existingPath);
      expect(apiClient.downloadCalls, 0);
    });

    test('downloadResource reuses file already on disk even without history', () async {
      final resource = _resource();
      final downloadsDir = Directory('${tempDir.path}/downloads');
      await downloadsDir.create(recursive: true);

      final baseFilename = _resourceBaseFilename(resource);
      final extension = _extensionForResource(resource);
      final filename = baseFilename.toLowerCase().endsWith('.$extension')
          ? '123_$baseFilename'
          : '123_$baseFilename.$extension';
      final existingFile = File('${downloadsDir.path}/$filename');
      await existingFile.writeAsString('existing');

      var alreadyDownloadedCalled = false;
      final file = await repository.downloadResource(
        resource,
        onProgress: (received, total) {},
        onAlreadyDownloaded: () {
          alreadyDownloadedCalled = true;
        },
      );

      expect(file.path, existingFile.path);
      expect(apiClient.downloadCalls, 0);
      expect(alreadyDownloadedCalled, isTrue);

      final downloads = await repository.getDownloads();
      expect(downloads, hasLength(1));
      expect(downloads.first.localPath, existingFile.path);
    });

    test('getExistingDownloadedFile removes stale history entries', () async {
      final resource = _resource();
      final stalePath = '${tempDir.path}/downloads/missing.pdf';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('download_history_v1', <String>[
        DownloadedFile(
          id: _stableResourceId(resource),
          url: resource.url,
          name: resource.name,
          type: resource.type.name,
          localPath: stalePath,
          downloadedAt: DateTime.now(),
          localArtworkPath: '',
        ).toRawJson(),
      ]);

      final existing = await repository.getExistingDownloadedFile(resource);
      final downloads = await repository.getDownloads();

      expect(existing, isNull);
      expect(downloads, isEmpty);
    });
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

String _stableResourceId(LessonResource resource) {
  return '${resource.type.name}:${resource.url}';
}

String _legacyResourceId(LessonResource resource) {
  return '${resource.type.name}:${resource.url.hashCode}';
}

String _resourceBaseFilename(LessonResource resource) {
  final normalized =
      resource.name.trim().isEmpty ? resource.type.name : resource.name.trim();
  return normalized
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_');
}

String _extensionForResource(LessonResource resource) {
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

class _FakeDownloadApiClient extends FakeApiClient {
  int downloadCalls = 0;
  final Set<String> failArtworkUrls = {};

  @override
  Future<Response<dynamic>> download(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    downloadCalls += 1;
    if (failArtworkUrls.contains(url)) {
      throw Exception('Simulated artwork download failure');
    }
    final file = File(savePath);
    await file.create(recursive: true);
    await file.writeAsString('downloaded');
    onReceiveProgress?.call(1, 1);
    return Response<dynamic>(
      requestOptions: RequestOptions(path: url),
      statusCode: 200,
      data: null,
    );
  }
}

class _TestDownloadRepository extends DownloadRepository {
  _TestDownloadRepository({required super.apiClient, required this.baseDirectory});

  final Directory baseDirectory;

  @override
  Future<Directory> getBaseDirectory() async => baseDirectory;
}
