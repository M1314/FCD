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

  group('LoginPage quick-login button', () {
    testWidgets(
      'lock icon is shown when biometrics unavailable but device auth is supported',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(storedEmail: 'user@example.com'),
        );
        final fakeAuth = _FakeLocalAuth(
          biometricsAvailable: false,
          deviceSupported: true,
        );

        await tester.pumpWidget(_wrap(session, LoginPage(localAuth: fakeAuth)));
        await tester.pumpAndSettle();

        final quickLoginButton = find.widgetWithText(
          OutlinedButton,
          'Ingresar como user@example.com',
        );

        // No biometric (face) icon.
        expect(find.byIcon(Icons.face), findsNothing);
        // Device auth quick-login button is shown with lock icon.
        expect(quickLoginButton, findsOneWidget);
        expect(
          find.descendant(of: quickLoginButton, matching: find.byIcon(Icons.lock_outline)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'quick-login button is hidden when biometrics unavailable and device auth unsupported',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(storedEmail: 'user@example.com'),
        );
        final fakeAuth = _FakeLocalAuth(
          biometricsAvailable: false,
          deviceSupported: false,
        );

        await tester.pumpWidget(_wrap(session, LoginPage(localAuth: fakeAuth)));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.face), findsNothing);
        expect(
          find.widgetWithText(OutlinedButton, 'Ingresar como user@example.com'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'no quick-login button shown when there is no stored account',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(), // storedEmail is null
        );
        final fakeAuth = _FakeLocalAuth(biometricsAvailable: false);

        await tester.pumpWidget(_wrap(session, LoginPage(localAuth: fakeAuth)));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.face), findsNothing);
        expect(find.byIcon(Icons.person_outline), findsNothing);
      },
    );

    testWidgets(
      'face icon is shown when biometrics available and email is stored',
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

    testWidgets(
      'pressing enter on empty password field without biometrics uses stored credentials when device auth is supported',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(storedEmail: 'user@example.com'),
        );
        final fakeAuth = _FakeLocalAuth(
          biometricsAvailable: false,
          deviceSupported: true,
        );

        await tester.pumpWidget(_wrap(session, LoginPage(localAuth: fakeAuth)));
        await tester.pumpAndSettle();

        // Both fields are empty; focus the password field and submit.
        await tester.showKeyboard(find.byType(TextFormField).last);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Stored-credentials path was taken (no manual-form validation error).
        expect(find.text('Ingresa tu correo.'), findsNothing);
        expect(
          find.text('No se encontraron credenciales guardadas.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'pressing enter on empty password field uses normal form validation when device auth is unsupported',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(storedEmail: 'user@example.com'),
        );
        final fakeAuth = _FakeLocalAuth(
          biometricsAvailable: false,
          deviceSupported: false,
        );

        await tester.pumpWidget(_wrap(session, LoginPage(localAuth: fakeAuth)));
        await tester.pumpAndSettle();

        await tester.showKeyboard(find.byType(TextFormField).last);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.text('Ingresa tu correo.'), findsOneWidget);
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
      'no snackbar when authenticate() returns false (silent cancel)',
      (tester) async {
        final session = SessionController.forTesting(
          apiClient: _FakeApiClient(storedEmail: 'user@example.com'),
        );
        final fakeAuth = _FakeLocalAuth(
          biometricsAvailable: true,
          authenticateResult: false,
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
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: child,
    ),
  );
}

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _FakeLocalAuth extends LocalAuthentication {
  _FakeLocalAuth({
    required this.biometricsAvailable,
    bool? deviceSupported,
    bool? authenticateResult,
    this.throwOnAuthenticate,
  })  : deviceSupported = deviceSupported ?? biometricsAvailable,
        authenticateResult = authenticateResult ?? (deviceSupported ?? biometricsAvailable);

  final bool biometricsAvailable;
  final bool deviceSupported;
  final bool authenticateResult;
  final Object? throwOnAuthenticate;

  @override
  Future<bool> get canCheckBiometrics async => biometricsAvailable;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (!biometricsAvailable) {
      return <BiometricType>[];
    }
    return <BiometricType>[BiometricType.face];
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    if (throwOnAuthenticate != null) throw throwOnAuthenticate!;
    return authenticateResult;
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

  @override
  Future<void> clearCredentials() async {}
}
