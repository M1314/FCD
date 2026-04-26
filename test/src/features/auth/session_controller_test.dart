import 'package:dio/dio.dart';
import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/core/storage/app_storage.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionController', () {
    test('loginWithStoredCredentials returns false when no credentials stored', () async {
      final apiClient = _FakeApiClient();
      final controller = SessionController.forTesting(apiClient: apiClient);

      final success = await controller.loginWithStoredCredentials();

      expect(success, isFalse);
      expect(controller.isUnauthenticated, isTrue);
      expect(controller.errorMessage, isNotNull);
    });

    test('clearSessionExpired clears the flag', () async {
      final apiClient = _FakeApiClient();
      final controller = SessionController.forTesting(apiClient: apiClient);

      controller.clearSessionExpired();

      expect(controller.sessionExpired, isFalse);
    });
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(dio: Dio(), storage: _FakeStorage());
}

class _FakeStorage extends AppStorage {
  @override
  Future<void> clearSession() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<int?> getUserId() async => null;

  @override
  Future<String?> getUserName() async => null;

  @override
  Future<String?> getUserEmail() async => null;

  @override
  Future<String?> getUserType() async => null;

  @override
  Future<void> saveAccessToken(String accessToken) async {}

  @override
  Future<void> savePassword(String password) async {}

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String userName,
    required String userEmail,
    required String userType,
  }) async {}
}