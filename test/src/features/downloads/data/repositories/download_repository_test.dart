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
      );
      final missing = DownloadedFile(
        id: '2',
        url: 'https://example.com/b.pdf',
        name: 'B',
        type: 'document',
        localPath: missingPath,
        downloadedAt: DateTime(2024, 1, 2),
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

    test('downloadResource reuses already-downloaded artwork on second call', () async {
      const iconUrl = 'https://example.com/icon2.png';
      final resource = LessonResource(
        type: LessonResourceType.audio,
        url: 'https://example.com/files/lesson2.mp3',
        name: 'Lección 2',
        order: 1,
        courseIconUrl: iconUrl,
      );

      // First download: downloads resource + artwork (2 calls)
      await repository.downloadResource(
        resource,
        onProgress: (received, total) {},
      );
      final callsAfterFirst = apiClient.downloadCalls;
      expect(callsAfterFirst, 2);

      // Clear history so the resource is re-downloaded (simulates a re-download scenario)
      await repository.clearHistory();

      // Second download: artwork file already exists on disk → only 1 new API call for resource
      await repository.downloadResource(
        resource,
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
        ).toRawJson(),
      ]);

      final file = await repository.downloadResource(
        resource,
        onProgress: (received, total) {},
      );

      expect(file.path, existingPath);
      expect(apiClient.downloadCalls, 0);
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
