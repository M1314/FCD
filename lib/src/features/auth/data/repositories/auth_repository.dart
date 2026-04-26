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
    await _storage.savePassword(password);
    _apiClient.setTokens(accessToken: accessToken, refreshToken: refreshToken);
    return session;
  }

  Future<AuthSession?> loginWithStoredCredentials() async {
    final email = await _storage.getUserEmail();
    final password = await _storage.getPassword();

    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return null;
    }

    try {
      return await login(email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String phone = '',
    String profession = '',
    String maritalStatus = '',
    String address = '',
    String city = '',
    String zipCode = '',
    String question1 = '',
    String question2 = '',
    bool question3 = false,
    bool question4 = false,
    String question5 = '',
    bool question6 = false,
    bool question7 = false,
    String question8 = '',
    DateTime? dateOfBirth,
  }) async {
    final payload = <String, dynamic>{
      'strEmail': email,
      'strFirstName': firstName,
      'strLastName': lastName,
      'strPassword': password,
      'strAddress': address,
      'strCity': city,
      'strZipCode': zipCode.isEmpty ? null : int.tryParse(zipCode),
      'strQuestion1': question1,
      'strQuestion2': question2,
      'blnQuestion3': question3,
      'blnQuestion4': question4,
      'strQuestion5': question5,
      'blnQuestion6': question6,
      'blnQuestion7': question7,
      'strQuestion8': question8,
      if (dateOfBirth != null) 'dteDateOfBirth': _formatDateTime(dateOfBirth),
      'dteRegistrationDate': _formatDateTime(DateTime.now()),
      'strPhone': phone,
      'strProfession': profession,
      'strMaritalStatus': maritalStatus,
      'strShippingAddresses': '[]',
    };

    final response = await _apiClient.post('/user', data: payload);
    final statusCode = response['intResponse'] as int? ?? 500;
    if (statusCode != 200) {
      throw AppException(
        response['strAnswer']?.toString() ?? 'No se pudo registrar el usuario.',
        statusCode: statusCode,
      );
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return local.toIso8601String().substring(0, 16);
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

  Future<void> logout({bool clearCredentials = false}) async {
    await _storage.clearSession();
    _apiClient.clearTokens();
    if (clearCredentials) {
      await _storage.clearCredentials();
    }
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
