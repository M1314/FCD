import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/features/courses/data/models/lesson_resource.dart';
import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;
  late _FakeApiClient apiClient;
  late _TestDownloadRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('download_repository_test');
    apiClient = _FakeApiClient();
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
        id: '${resource.type.name}:${resource.url.hashCode}',
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

  test('downloadResource downloads and records history when missing', () async {
    final resource = _resource();

    final file = await repository.downloadResource(
      resource,
      onProgress: (received, total) {},
    );
    final downloads = await repository.getDownloads();

    expect(apiClient.downloadCalls, 1);
    expect(await file.exists(), isTrue);
    expect(downloads, hasLength(1));
    expect(downloads.first.url, resource.url);
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

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(dio: Dio());

  int downloadCalls = 0;

  @override
  Future<Response<dynamic>> download(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    downloadCalls += 1;
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
