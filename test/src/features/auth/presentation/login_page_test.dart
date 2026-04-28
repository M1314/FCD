import 'package:dio/dio.dart';
import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/core/storage/app_storage.dart';
import 'package:fcd_app/src/features/auth/presentation/login_page.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    // Prevent google_fonts from trying to load fonts from the network/asset
    // bundle during widget tests (there is no compiled AssetManifest in tests).
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  // ─── Fix 3: password validator ───────────────────────────────────────────

  group('validateLoginPassword', () {
    test('allows null input', () {
      expect(validateLoginPassword(null), isNull);
    });

    test('allows empty string', () {
      expect(validateLoginPassword(''), isNull);
    });

    test('rejects non-empty password shorter than 8 characters', () {
      expect(validateLoginPassword('abc'), isNotNull);
      expect(validateLoginPassword('1234567'), isNotNull);
    });

    test('accepts password of exactly 8 characters', () {
      expect(validateLoginPassword('abcdefgh'), isNull);
    });

    test('accepts password longer than 8 characters', () {
      expect(validateLoginPassword('password123'), isNull);
    });
  });

  // ─── Fix 3: form submission with empty password (end-to-end) ─────────────

  group('LoginPage password field — form submission', () {
    testWidgets(
      'form submits normally with valid email and empty password (no client-side block)',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(),
        );

        await tester.pumpWidget(
          _wrap(session, LoginPage(localAuth: _FakeLocalAuth(biometricsAvailable: false))),
        );
        await tester.pumpAndSettle();

        // Fill in a valid email, leave password empty (default empty).
        await tester.enterText(find.byType(TextFormField).first, 'user@example.com');

        // Tap the submit button.
        await tester.tap(find.text('Ingresar'));
        await tester.pumpAndSettle();

        // No client-side password validation error should be shown.
        expect(find.text('Mínimo 8 caracteres.'), findsNothing);
        // The request must have reached the (fake) server — proof that the form
        // did not block submission. The fake server returns {} which causes the
        // repository to surface a generic server error.
        expect(find.text('No se pudo iniciar sesión.'), findsOneWidget);
      },
    );
  });

  // ─── Fix 1: biometric button visibility ──────────────────────────────────

  group('LoginPage biometric button', () {
    testWidgets(
      'is not shown when device biometrics are unavailable',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(storedEmail: 'user@example.com'),
        );
        final fakeAuth = _FakeLocalAuth(biometricsAvailable: false);

        await tester.pumpWidget(_wrap(session, LoginPage(localAuth: fakeAuth)));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.face), findsNothing);
      },
    );

    testWidgets(
      'is shown when biometrics available and email is stored',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(storedEmail: 'user@example.com'),
        );
        final fakeAuth = _FakeLocalAuth(biometricsAvailable: true);

        await tester.pumpWidget(_wrap(session, LoginPage(localAuth: fakeAuth)));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.face), findsOneWidget);
      },
    );
  });

  // ─── Fix 2: biometric cancel / error handling ─────────────────────────────

  group('LoginPage biometric cancel / error handling', () {
    testWidgets(
      'no snackbar when user cancels biometric (userCanceled)',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(storedEmail: 'user@example.com'),
        );
        final fakeAuth = _FakeLocalAuth(
          biometricsAvailable: true,
          throwOnAuthenticate: const LocalAuthException(
            code: LocalAuthExceptionCode.userCanceled,
          ),
        );

        await tester.pumpWidget(_wrap(session, LoginPage(localAuth: fakeAuth)));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.face));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'generic error snackbar shown for non-cancel biometric errors',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(storedEmail: 'user@example.com'),
        );
        final fakeAuth = _FakeLocalAuth(
          biometricsAvailable: true,
          throwOnAuthenticate: const LocalAuthException(
            code: LocalAuthExceptionCode.deviceError,
          ),
        );

        await tester.pumpWidget(_wrap(session, LoginPage(localAuth: fakeAuth)));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.face));
        await tester.pumpAndSettle();

        expect(
          find.text('No se pudo autenticar. Inténtalo de nuevo.'),
          findsOneWidget,
        );
      },
    );
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _wrap(SessionController session, Widget child) {
  return ChangeNotifierProvider<SessionController>.value(
    value: session,
    child: MaterialApp(home: child),
  );
}

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _FakeLocalAuth extends LocalAuthentication {
  _FakeLocalAuth({
    required this.biometricsAvailable,
    this.throwOnAuthenticate,
  });

  final bool biometricsAvailable;
  final Object? throwOnAuthenticate;

  @override
  Future<bool> get canCheckBiometrics async => biometricsAvailable;

  @override
  Future<bool> isDeviceSupported() async => biometricsAvailable;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    if (throwOnAuthenticate != null) throw throwOnAuthenticate!;
    return biometricsAvailable;
  }
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({String? storedEmail})
      : super(dio: Dio(), storage: _FakeStorage(storedEmail: storedEmail));

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async =>
      <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async =>
      <String, dynamic>{};
}

class _FakeStorage extends AppStorage {
  _FakeStorage({this.storedEmail});

  final String? storedEmail;

  @override
  Future<String?> getUserEmail() async => storedEmail;

  @override
  Future<String?> getPassword() async => null;

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
  Future<String?> getUserType() async => null;

  @override
  Future<void> saveAccessToken(String accessToken) async {}

  @override
  Future<void> savePassword(String password) async {}

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
