import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppStorage {
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String userEmailKey = 'user_email';
  static const String userTypeKey = 'user_type';
  static const String userPasswordKey = 'user_password';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String userName,
    required String userEmail,
    required String userType,
  }) async {
    await _secureStorage.write(key: accessTokenKey, value: accessToken);
    await _secureStorage.write(key: refreshTokenKey, value: refreshToken);
    await _secureStorage.write(key: userIdKey, value: userId.toString());
    await _secureStorage.write(key: userNameKey, value: userName);
    await _secureStorage.write(key: userEmailKey, value: userEmail);
    await _secureStorage.write(key: userTypeKey, value: userType);
  }

  Future<void> savePassword(String password) async {
    await _secureStorage.write(key: userPasswordKey, value: password);
  }

  Future<String?> getPassword() async {
    return _secureStorage.read(key: userPasswordKey);
  }

  Future<void> saveAccessToken(String accessToken) async {
    await _secureStorage.write(key: accessTokenKey, value: accessToken);
  }

  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: refreshTokenKey);
  }

  Future<int?> getUserId() async {
    final value = await _secureStorage.read(key: userIdKey);
    return value != null ? int.tryParse(value) : null;
  }

  Future<String?> getUserName() async {
    return _secureStorage.read(key: userNameKey);
  }

  Future<String?> getUserEmail() async {
    return _secureStorage.read(key: userEmailKey);
  }

  Future<String?> getUserType() async {
    return _secureStorage.read(key: userTypeKey);
  }

Future<void> clearSession() async {
    await _secureStorage.delete(key: accessTokenKey);
    await _secureStorage.delete(key: refreshTokenKey);
    await _secureStorage.delete(key: userIdKey);
    await _secureStorage.delete(key: userNameKey);
    await _secureStorage.delete(key: userTypeKey);
  }

  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: userPasswordKey);
  }
}
