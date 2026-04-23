import 'package:fcd_app/src/features/auth/presentation/biometric_authenticator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalBiometricAuthenticator', () {
    test(
      'isAvailable returns true only when biometrics are supported',
      () async {
        final authenticator = LocalBiometricAuthenticator(
          client: _FakeBiometricAuthClient(
            canCheckBiometricsValue: true,
            isDeviceSupportedValue: true,
          ),
        );

        final isAvailable = await authenticator.isAvailable();

        expect(isAvailable, isTrue);
      },
    );

    test('authenticate returns false without biometrics support', () async {
      final client = _FakeBiometricAuthClient(
        canCheckBiometricsValue: false,
        isDeviceSupportedValue: true,
      );
      final authenticator = LocalBiometricAuthenticator(client: client);

      final authenticated = await authenticator.authenticate();

      expect(authenticated, isFalse);
      expect(client.authenticateCallCount, 0);
    });

    test('authenticate returns client result when available', () async {
      final client = _FakeBiometricAuthClient(
        canCheckBiometricsValue: true,
        isDeviceSupportedValue: true,
        authenticateValue: true,
      );
      final authenticator = LocalBiometricAuthenticator(client: client);

      final authenticated = await authenticator.authenticate();

      expect(authenticated, isTrue);
      expect(client.authenticateCallCount, 1);
    });

    test('authenticate handles platform exceptions', () async {
      final authenticator = LocalBiometricAuthenticator(
        client: _FakeBiometricAuthClient(
          canCheckBiometricsValue: true,
          isDeviceSupportedValue: true,
          authenticateError: PlatformException(code: 'NotAvailable'),
        ),
      );

      final authenticated = await authenticator.authenticate();

      expect(authenticated, isFalse);
    });
  });
}

class _FakeBiometricAuthClient implements BiometricAuthClient {
  _FakeBiometricAuthClient({
    required this.canCheckBiometricsValue,
    required this.isDeviceSupportedValue,
    this.authenticateValue = false,
    this.authenticateError,
  });

  final bool canCheckBiometricsValue;
  final bool isDeviceSupportedValue;
  final bool authenticateValue;
  final PlatformException? authenticateError;
  int authenticateCallCount = 0;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCallCount++;
    final error = authenticateError;
    if (error != null) {
      throw error;
    }
    return authenticateValue;
  }

  @override
  Future<bool> canCheckBiometrics() async => canCheckBiometricsValue;

  @override
  Future<bool> isDeviceSupported() async => isDeviceSupportedValue;
}
