import 'package:dio/dio.dart';
import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/core/storage/app_storage.dart';
import 'package:fcd_app/src/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthRepository', () {
    group('login', () {
      test('saves password after successful login', () async {
        final storage = _TestStorage();
        final apiClient = _TestApiClient(
          onPost: (path, {data, queryParameters, authenticated = false}) async {
            return {
              'intResponse': 200,
              'access_token': 'access123',
              'refresh_token': 'refresh123',
              'Result': {
                'user': {
                  'idusuarioCliente': 1,
                  'nombre': 'Test User',
                  'email': 'test@example.com',
                  'telefono': '',
                  'apellidos': '',
                },
              },
            };
          },
        );

        final repository = AuthRepository(apiClient: apiClient, storage: storage);

        await repository.login(email: 'test@example.com', password: 'password123');

        expect(storage.savedPassword, 'password123');
      });

      test('loginWithStoredCredentials returns null when no credentials stored', () async {
        final storage = _TestStorage();
        final apiClient = _TestApiClient();

        final repository = AuthRepository(apiClient: apiClient, storage: storage);

        final session = await repository.loginWithStoredCredentials();

        expect(session, isNull);
      });

      test('loginWithStoredCredentials returns session when credentials exist', () async {
        final storage = _TestStorage()
          ..savedEmail = 'test@example.com'
          ..savedPassword = 'password123';
        final apiClient = _TestApiClient(
          onPost: (path, {data, queryParameters, authenticated = false}) async {
            expect(path, '/login');
            expect(data, {
              'strEmail': 'test@example.com',
              'strPassword': 'password123',
            });
            return {
              'intResponse': 200,
              'access_token': 'access123',
              'refresh_token': 'refresh123',
              'Result': {
                'user': {
                  'idusuarioCliente': 1,
                  'nombre': 'Test User',
                  'email': 'test@example.com',
                  'telefono': '',
                  'apellidos': '',
                },
              },
            };
          },
        );

        final repository = AuthRepository(apiClient: apiClient, storage: storage);

        final session = await repository.loginWithStoredCredentials();

        expect(session, isNotNull);
        expect(session!.user.email, 'test@example.com');
      });
    });

    group('logout', () {
      test('clears session but keeps credentials by default', () async {
        final storage = _TestStorage()
          ..savedEmail = 'test@example.com'
          ..savedPassword = 'password123';
        final apiClient = _TestApiClient();

        final repository = AuthRepository(apiClient: apiClient, storage: storage);

        await repository.logout();

        expect(storage.sessionCleared, isTrue);
        expect(storage.credentialsCleared, isFalse);
        expect(storage.savedEmail, 'test@example.com');
        expect(storage.savedPassword, 'password123');
      });

      test('clears credentials when clearCredentials is true', () async {
        final storage = _TestStorage()
          ..savedEmail = 'test@example.com'
          ..savedPassword = 'password123';
        final apiClient = _TestApiClient();

        final repository = AuthRepository(apiClient: apiClient, storage: storage);

        await repository.logout(clearCredentials: true);

        expect(storage.sessionCleared, isTrue);
        expect(storage.credentialsCleared, isTrue);
      });
    });
  });
}

class _TestStorage extends AppStorage {
  String? savedEmail;
  String? savedPassword;
  bool sessionCleared = false;
  bool credentialsCleared = false;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String userName,
    required String userEmail,
    required String userType,
  }) async {
    savedEmail = userEmail;
  }

  @override
  Future<void> savePassword(String password) async {
    savedPassword = password;
  }

  @override
  Future<String?> getUserEmail() async => savedEmail;

  @override
  Future<String?> getPassword() async => savedPassword;

  @override
  Future<void> clearSession() async {
    sessionCleared = true;
  }

  @override
  Future<void> clearCredentials() async {
    credentialsCleared = true;
  }
}

class _TestApiClient extends ApiClient {
  _TestApiClient({this.onPost})
      : super(dio: Dio(), storage: _FakeAppStorage());

  final Future<Map<String, dynamic>> Function(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool authenticated,
  })? onPost;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    if (onPost != null) {
      return onPost!(
        path,
        data: data,
        queryParameters: queryParameters,
        authenticated: authenticated,
      );
    }
    return {};
  }
}

class _FakeAppStorage extends AppStorage {
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
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String userName,
    required String userEmail,
    required String userType,
  }) async {}
}