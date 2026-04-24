import 'package:dio/dio.dart';
import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/core/storage/app_storage.dart';
import 'package:fcd_app/src/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('register sends the full payload with working defaults', () async {
    final apiClient = _FakeApiClient(
      onPost: (path, {data, queryParameters, authenticated = false}) async {
        expect(path, '/user');
        expect(authenticated, isFalse);
        final payload = data as Map<String, dynamic>;
        expect(payload['strEmail'], 'pedroprueba@gmail.com');
        expect(payload['strFirstName'], 'Prueba');
        expect(payload['strLastName'], 'Prueba');
        expect(payload['strPassword'], 'pruebapedro');
        expect(payload['strAddress'], '');
        expect(payload['strCity'], '');
        expect(payload['strZipCode'], isNull);
        expect(payload['blnQuestion3'], isFalse);
        expect(payload['blnQuestion4'], isFalse);
        expect(payload['blnQuestion6'], isFalse);
        expect(payload['blnQuestion7'], isFalse);
        expect(payload['strShippingAddresses'], '[]');
        expect(payload['dteDateOfBirth'], '2011-04-24T01:45');
        expect(payload['dteRegistrationDate'], isA<String>());
        return <String, dynamic>{'intResponse': 200, 'strAnswer': 'Correo enviado'};
      },
    );

    final repository = AuthRepository(apiClient: apiClient, storage: _FakeStorage());

    await repository.register(
      firstName: 'Prueba',
      lastName: 'Prueba',
      email: 'pedroprueba@gmail.com',
      password: 'pruebapedro',
      dateOfBirth: DateTime(2011, 4, 24, 1, 45),
    );

    expect(apiClient.postCalls, hasLength(1));
  });
}

class _FakeApiClient extends _BaseFakeApiClient {
  _FakeApiClient({this.onPost}) : super(dio: Dio());

  final Future<Map<String, dynamic>> Function(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool authenticated,
  })? onPost;

  final List<_PostCall> postCalls = <_PostCall>[];

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    postCalls.add(
      _PostCall(
        path: path,
        data: data,
        queryParameters: queryParameters,
        authenticated: authenticated,
      ),
    );
    if (onPost != null) {
      return onPost!(
        path,
        data: data,
        queryParameters: queryParameters,
        authenticated: authenticated,
      );
    }
    return <String, dynamic>{};
  }
}

class _BaseFakeApiClient extends ApiClient {
  _BaseFakeApiClient({required super.dio});
}

class _PostCall {
  const _PostCall({
    required this.path,
    required this.data,
    required this.queryParameters,
    required this.authenticated,
  });

  final String path;
  final dynamic data;
  final Map<String, dynamic>? queryParameters;
  final bool authenticated;
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
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String userName,
    required String userEmail,
    required String userType,
  }) async {}
}
