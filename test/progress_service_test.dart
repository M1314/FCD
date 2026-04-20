import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        'progress.study': true,
        'progress.practice': true,
        'progress.notes': false,
      }),
      67,
    );
  });

  test('completionPercent handles all snippets completed', () {
    final service = ProgressService();
    expect(
      service.completionPercent({
        'progress.study': true,
      }),
      100,
    );
  });

  test('completionPercent rounds partial percentages', () {
    final service = ProgressService();
    expect(
      service.completionPercent({
        'progress.study': true,
        'progress.practice': false,
        'progress.notes': false,
      }),
      33,
    );
  });

  test('labelForKey returns translated label when key exists', () {
    final service = ProgressService();
    expect(service.labelForKey('progress.study'), 'Estudié 20 minutos');
  });

  test('labelForKey returns storage key when no label exists', () {
    final service = ProgressService();
    expect(service.labelForKey('progress.unknown'), 'progress.unknown');
  });

  test('saveSnippet and loadSnippets persist values', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ProgressService();

    await service.saveSnippet('progress.study', true);
    final snippets = await service.loadSnippets();

    expect(snippets['progress.study'], true);
    expect(snippets['progress.practice'], false);
    expect(snippets['progress.notes'], false);
  });
}
