import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/core/storage/app_storage.dart';
import 'package:fcd_app/src/features/ai/data/repositories/ai_chat_repository.dart';
import 'package:fcd_app/src/features/auth/data/models/auth_session.dart';
import 'package:fcd_app/src/features/auth/data/models/auth_user.dart';
import 'package:fcd_app/src/features/auth/data/repositories/auth_repository.dart';
import 'package:fcd_app/src/features/courses/data/repositories/course_repository.dart';
import 'package:flutter/foundation.dart';

enum SessionStatus { checking, unauthenticated, authenticated }

class SessionController extends ChangeNotifier {
  SessionController()
    : _storage = AppStorage(),
      _status = SessionStatus.checking {
    _apiClient = ApiClient(
      onUnauthorized: _handleUnauthorized,
      onTokenRefreshed: _handleTokenRefreshed,
    );

    _authRepository = AuthRepository(apiClient: _apiClient, storage: _storage);
    courseRepository = CourseRepository(apiClient: _apiClient);
    aiChatRepository = AiChatRepository(apiClient: _apiClient);
  }

  SessionController.forTesting({required ApiClient apiClient})
    : _storage = AppStorage(),
      _apiClient = apiClient,
      _status = SessionStatus.checking {
    _authRepository = AuthRepository(apiClient: _apiClient, storage: _storage);
    courseRepository = CourseRepository(apiClient: _apiClient);
    aiChatRepository = AiChatRepository(apiClient: _apiClient);
  }

  final AppStorage _storage;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;

  late final CourseRepository courseRepository;
  late final AiChatRepository aiChatRepository;

  SessionStatus _status;
  AuthUser? _user;
  String? _errorMessage;

  SessionStatus get status => _status;
  AuthUser? get user => _user;
  String? get errorMessage => _errorMessage;
  ApiClient get apiClient => _apiClient;

  bool get isChecking => _status == SessionStatus.checking;
  bool get isAuthenticated => _status == SessionStatus.authenticated;
  bool get isUnauthenticated => _status == SessionStatus.unauthenticated;

  Future<void> bootstrap() async {
    _status = SessionStatus.checking;
    notifyListeners();

    final session = await _authRepository.restoreSession();
    if (session == null) {
      _user = null;
      _status = SessionStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _applySession(session);
  }

  Future<bool> login({required String email, required String password}) async {
    _errorMessage = null;
    _status = SessionStatus.checking;
    notifyListeners();

    try {
      final session = await _authRepository.login(
        email: email,
        password: password,
      );
      _applySession(session);
      return true;
    } catch (error) {
      _status = SessionStatus.unauthenticated;
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _status = SessionStatus.checking;
    notifyListeners();

    try {
      await _authRepository.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
      _status = SessionStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _status = SessionStatus.unauthenticated;
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    _errorMessage = null;
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  void _applySession(AuthSession session) {
    _user = session.user;
    _errorMessage = null;
    _status = SessionStatus.authenticated;
    notifyListeners();
  }

  Future<void> _handleTokenRefreshed(String accessToken) {
    return _authRepository.updateAccessToken(accessToken);
  }

  Future<void> _handleUnauthorized() async {
    if (_status == SessionStatus.unauthenticated) {
      return;
    }
    await _authRepository.logout();
    _user = null;
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }
}
