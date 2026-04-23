import 'package:fcd_app/src/core/errors/app_exception.dart';
import 'package:fcd_app/src/core/storage/app_storage.dart';
import 'package:fcd_app/src/features/auth/data/models/auth_session.dart';
import 'package:fcd_app/src/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../test_helpers/fake_api_client.dart';

void main() {
  group('AuthRepository', () {
    test('login stores credentials for biometric login', () async {
      final apiClient = FakeApiClient(
        onPost: (_, {data, queryParameters, authenticated = false}) async =>
            _loginResponse(),
      );
      final storage = _FakeAppStorage();
      final repository = AuthRepository(apiClient: apiClient, storage: storage);

      await repository.login(email: 'test@correo.com', password: 'secret123');

      expect(storage.savedEmail, 'test@correo.com');
      expect(storage.savedPassword, 'secret123');
    });

    test(
      'loginWithSavedCredentials logs in using stored credentials',
      () async {
        final apiClient = FakeApiClient(
          onPost: (_, {data, queryParameters, authenticated = false}) async =>
              _loginResponse(),
        );
        final storage = _FakeAppStorage(
          credentials: const SavedLoginCredentials(
            email: 'saved@correo.com',
            password: 'abc12345',
          ),
        );
        final repository = AuthRepository(
          apiClient: apiClient,
          storage: storage,
        );

        final session = await repository.loginWithSavedCredentials();

        expect(session, isA<AuthSession>());
        expect(apiClient.postCalls, hasLength(1));
        expect(apiClient.postCalls.single.path, '/login');
        expect(apiClient.postCalls.single.data, <String, dynamic>{
          'strEmail': 'saved@correo.com',
          'strPassword': 'abc12345',
        });
      },
    );

    test(
      'loginWithSavedCredentials throws when credentials are missing',
      () async {
        final apiClient = FakeApiClient();
        final storage = _FakeAppStorage();
        final repository = AuthRepository(
          apiClient: apiClient,
          storage: storage,
        );

        expect(
          repository.loginWithSavedCredentials(),
          throwsA(isA<AppException>()),
        );
        expect(apiClient.postCalls, isEmpty);
      },
    );
  });
}

class _FakeAppStorage extends AppStorage {
  _FakeAppStorage({this.credentials});

  SavedLoginCredentials? credentials;
  String? savedEmail;
  String? savedPassword;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String userName,
    required String userEmail,
    required String userType,
  }) async {}

  @override
  Future<void> saveLoginCredentials({
    required String email,
    required String password,
  }) async {
    savedEmail = email;
    savedPassword = password;
    credentials = SavedLoginCredentials(email: email, password: password);
  }

  @override
  Future<SavedLoginCredentials?> getSavedLoginCredentials() async =>
      credentials;
}

Map<String, dynamic> _loginResponse() {
  return <String, dynamic>{
    'intResponse': 200,
    'access_token': 'token',
    'refresh_token': 'refresh',
    'Result': <String, dynamic>{
      'user': <String, dynamic>{
        'idusuarioCliente': 7,
        'nombre': 'Usuario',
        'email': 'test@correo.com',
      },
    },
  };
}
