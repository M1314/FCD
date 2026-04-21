import 'package:fcd_app/src/core/utils/json_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('readInt', () {
    test('parses string values with whitespace', () {
      final json = <String, dynamic>{'value': ' 42 '};

      final result = readInt(json, const <String>['value']);

      expect(result, 42);
    });
  });

  group('readDouble', () {
    test('parses string values with whitespace', () {
      final json = <String, dynamic>{'value': ' 12.5 '};

      final result = readDouble(json, const <String>['value']);

      expect(result, 12.5);
    });
  });

  group('readBool', () {
    test('uses fallback for unrecognized string values', () {
      final json = <String, dynamic>{'value': 'unknown'};

      final result = readBool(json, const <String>['value'], fallback: true);

      expect(result, isTrue);
    });
  });
}
