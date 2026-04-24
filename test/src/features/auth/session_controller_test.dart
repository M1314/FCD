import 'package:dio/dio.dart';
import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/core/storage/app_storage.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('register maps success to unauthenticated state', () async {
    final apiClient = _FakeApiClient(
      onPost: (path, {data, queryParameters, authenticated = false}) async {
        if (path == '/user') {
          return <String, dynamic>{'intResponse': 200, 'strAnswer': 'Correo enviado'};
        }
        throw StateError('Unexpected path: $path');
      },
    );

    final controller = SessionController.forTesting(apiClient: apiClient);
    final result = await controller.register(
      firstName: 'Prueba',
      lastName: 'Prueba',
      email: 'pedroprueba@gmail.com',
      password: 'pruebapedro',
    );

    expect(result, isTrue);
    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.errorMessage, isNull);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.onPost}) : super(dio: Dio());

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
    return <String, dynamic>{};
  }
}
