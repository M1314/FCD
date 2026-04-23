import 'package:local_auth/local_auth.dart';

abstract class BiometricAuthenticator {
  Future<bool> isAvailable();
  Future<bool> authenticate();
}

abstract class BiometricAuthClient {
  Future<bool> canCheckBiometrics();
  Future<bool> isDeviceSupported();
  Future<bool> authenticate({required String localizedReason});
}

class LocalAuthenticationClient implements BiometricAuthClient {
  LocalAuthenticationClient({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<bool> canCheckBiometrics() => _localAuthentication.canCheckBiometrics;

  @override
  Future<bool> isDeviceSupported() => _localAuthentication.isDeviceSupported();

  @override
  Future<bool> authenticate({required String localizedReason}) {
    return _localAuthentication.authenticate(
      localizedReason: localizedReason,
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}

class LocalBiometricAuthenticator implements BiometricAuthenticator {
  LocalBiometricAuthenticator({BiometricAuthClient? client})
    : _client = client ?? LocalAuthenticationClient();

  final BiometricAuthClient _client;

  @override
  Future<bool> isAvailable() async {
    try {
      final canCheckBiometrics = await _client.canCheckBiometrics();
      if (!canCheckBiometrics) {
        return false;
      }
      return await _client.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      if (!await isAvailable()) {
        return false;
      }
      return await _client.authenticate(
        localizedReason: 'Usa Face ID para iniciar sesión.',
      );
    } on Exception {
      return false;
    }
  }
}
