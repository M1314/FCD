import 'dart:io';

import 'package:fcd_app/src/features/downloads/data/models/downloaded_file.dart';
import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../test_helpers/fake_api_client.dart';

void main() {
  group('DownloadRepository.removeMissingDownloads', () {
    test('removes entries whose local file does not exist', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'fcd-download-test',
      );
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

      final removed = await repository.removeMissingDownloads();
      final current = await repository.getDownloads();

      expect(removed, 1);
      expect(current, hasLength(1));
      expect(current.single.id, '1');

      await tempDir.delete(recursive: true);
    });

    test('returns 0 when all files still exist', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'fcd-download-test',
      );
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

      final removed = await repository.removeMissingDownloads();
      final current = await repository.getDownloads();

      expect(removed, 0);
      expect(current, hasLength(1));
      expect(current.single.id, '1');

      await tempDir.delete(recursive: true);
    });
  });
}
