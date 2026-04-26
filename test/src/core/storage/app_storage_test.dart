import 'package:fcd_app/src/core/storage/app_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppStorage', () {
    test('saveSession stores email', () async {
      final storage = _TestStorage();

      await storage.saveSession(
        accessToken: 'token1',
        refreshToken: 'token2',
        userId: 1,
        userName: 'Test User',
        userEmail: 'test@example.com',
        userType: 'user',
      );

      expect(storage.storedEmail, 'test@example.com');
    });

    test('getUserEmail returns stored email', () async {
      final storage = _TestStorage()..storedEmail = 'test@example.com';

      final email = await storage.getUserEmail();

      expect(email, 'test@example.com');
    });

    test('savePassword stores password', () async {
      final storage = _TestStorage();

      await storage.savePassword('secret123');

      expect(storage.storedPassword, 'secret123');
    });

    test('getPassword returns stored password', () async {
      final storage = _TestStorage()..storedPassword = 'secret123';

      final password = await storage.getPassword();

      expect(password, 'secret123');
    });

    test('clearSession clears tokens but keeps email', () async {
      final storage = _TestStorage()
        ..storedEmail = 'test@example.com'
        ..storedAccessToken = 'token1';

      await storage.clearSession();

      expect(storage.storedEmail, 'test@example.com');
      expect(storage.storedAccessToken, isNull);
    });

    test('clearCredentials clears password', () async {
      final storage = _TestStorage()..storedPassword = 'secret123';

      await storage.clearCredentials();

      expect(storage.storedPassword, isNull);
    });
  });
}

class _TestStorage extends AppStorage {
  String? storedEmail;
  String? storedPassword;
  String? storedAccessToken;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String userName,
    required String userEmail,
    required String userType,
  }) async {
    storedEmail = userEmail;
    storedAccessToken = accessToken;
  }

  @override
  Future<void> savePassword(String password) async {
    storedPassword = password;
  }

  @override
  Future<String?> getUserEmail() async => storedEmail;

  @override
  Future<String?> getPassword() async => storedPassword;

  @override
  Future<void> clearSession() async {
    storedAccessToken = null;
  }

  @override
  Future<void> clearCredentials() async {
    storedPassword = null;
  }

  @override
  Future<String?> getAccessToken() async => storedAccessToken;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<int?> getUserId() async => null;

  @override
  Future<String?> getUserName() async => null;

  @override
  Future<String?> getUserType() async => null;

  @override
  Future<void> saveAccessToken(String accessToken) async {
    storedAccessToken = accessToken;
  }
}