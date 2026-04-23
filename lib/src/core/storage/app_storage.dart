import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedLoginCredentials {
  const SavedLoginCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

class AppStorage {
  AppStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String userEmailKey = 'user_email';
  static const String userTypeKey = 'user_type';
  static const String loginEmailKey = 'login_email';
  static const String loginPasswordKey = 'login_password';

  final FlutterSecureStorage _secureStorage;

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String userName,
    required String userEmail,
    required String userType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accessTokenKey, accessToken);
    await prefs.setString(refreshTokenKey, refreshToken);
    await prefs.setInt(userIdKey, userId);
    await prefs.setString(userNameKey, userName);
    await prefs.setString(userEmailKey, userEmail);
    await prefs.setString(userTypeKey, userType);
  }

  Future<void> saveAccessToken(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accessTokenKey, accessToken);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(refreshTokenKey);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(userIdKey);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userNameKey);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userEmailKey);
  }

  Future<String?> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userTypeKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
    await prefs.remove(userIdKey);
    await prefs.remove(userNameKey);
    await prefs.remove(userEmailKey);
    await prefs.remove(userTypeKey);
  }

  Future<void> saveLoginCredentials({
    required String email,
    required String password,
  }) async {
    await _secureStorage.write(key: loginEmailKey, value: email);
    await _secureStorage.write(key: loginPasswordKey, value: password);
  }

  Future<SavedLoginCredentials?> getSavedLoginCredentials() async {
    final email = await _secureStorage.read(key: loginEmailKey);
    final password = await _secureStorage.read(key: loginPasswordKey);

    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }

    return SavedLoginCredentials(email: email, password: password);
  }

  Future<bool> hasSavedLoginCredentials() async {
    return (await getSavedLoginCredentials()) != null;
  }
}
