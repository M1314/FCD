import 'package:fcd_app/src/core/errors/app_exception.dart';
import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/core/storage/app_storage.dart';
import 'package:fcd_app/src/features/auth/data/models/auth_session.dart';
import 'package:fcd_app/src/features/auth/data/models/auth_user.dart';

class AuthRepository {
  AuthRepository({required ApiClient apiClient, required AppStorage storage})
    : _apiClient = apiClient,
      _storage = storage;

  final ApiClient _apiClient;
  final AppStorage _storage;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final payload = await _apiClient.post(
      '/login',
      data: <String, dynamic>{'strEmail': email, 'strPassword': password},
    );

    final statusCode = payload['intResponse'] as int? ?? 500;
    if (statusCode != 200) {
      throw AppException(
        payload['strAnswer']?.toString() ?? 'No se pudo iniciar sesion.',
        statusCode: statusCode,
      );
    }

    final accessToken = payload['access_token']?.toString() ?? '';
    final refreshToken = payload['refresh_token']?.toString() ?? '';
    final user = AuthUser.fromLoginResponse(payload);

    if (accessToken.isEmpty || refreshToken.isEmpty || user.id == 0) {
      throw const AppException('La sesion recibida es invalida.');
    }

    final session = AuthSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    await _persistSession(session);
    _apiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);
    return session;
  }

  Future<AuthSession?> restoreSession() async {
    final accessToken = await _storage.getAccessToken();
    final refreshToken = await _storage.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    _apiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);

    try {
      final payload = await _apiClient.postWithHeaders(
        '/refresh',
        data: '',
        headers: <String, dynamic>{'Authorization': 'Bearer $refreshToken'},
      );

      final statusCode = payload['intResponse'] as int? ?? 500;
      if (statusCode != 200) {
        await logout();
        return null;
      }

      final newAccessToken = payload['access_token']?.toString() ?? '';
      if (newAccessToken.isEmpty) {
        await logout();
        return null;
      }

      final user = AuthUser.fromRefreshResponse(payload);
      if (user.id == 0) {
        await logout();
        return null;
      }

      final session = AuthSession(
        user: user,
        accessToken: newAccessToken,
        refreshToken: refreshToken,
      );

      await _persistSession(session);
      _apiClient.setTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      return session;
    } on AppException {
      await logout();
      return null;
    }
  }

  Future<void> updateAccessToken(String accessToken) {
    return _storage.saveAccessToken(accessToken);
  }

  Future<void> logout() async {
    await _storage.clearSession();
    _apiClient.clearTokens();
  }

  Future<void> _persistSession(AuthSession session) async {
    await _storage.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      userId: session.user.id,
      userName: session.user.name,
      userEmail: session.user.email,
      userType: session.user.type,
    );
  }
}
