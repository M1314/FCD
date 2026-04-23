import 'package:fcd_app/src/core/errors/app_exception.dart';
import 'package:fcd_app/src/core/errors/error_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('userMessageFromError', () {
    test('returns AppException message when present', () {
      final message = userMessageFromError(
        const AppException('Mensaje especifico'),
        fallbackMessage: 'Fallback',
      );

      expect(message, 'Mensaje especifico');
    });

    test('returns fallback when AppException message is blank', () {
      final message = userMessageFromError(
        const AppException('   '),
        fallbackMessage: 'Fallback',
      );

      expect(message, 'Fallback');
    });

    test('returns fallback for non-AppException errors', () {
      final message = userMessageFromError(
        StateError('boom'),
        fallbackMessage: 'Fallback',
      );

      expect(message, 'Fallback');
    });
  });
}
