import 'package:flutter_test/flutter_test.dart';

import 'package:fcd/services/progress_service.dart';

void main() {
  test('completionPercent handles empty map', () {
    final service = ProgressService();
    expect(service.completionPercent({}), 0);
  });

  test('completionPercent calculates expected percentage', () {
    final service = ProgressService();
    expect(
      service.completionPercent({
        'Estudié 20 minutos': true,
        'Hice el ejercicio práctico': true,
        'Anoté una reflexión breve': false,
      }),
      67,
    );
  });
}
