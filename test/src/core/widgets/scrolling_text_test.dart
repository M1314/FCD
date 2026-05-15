import 'package:fcd_app/src/core/widgets/scrolling_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    required String text,
    double width = 140,
  }) {
    return MaterialApp(
      home: Material(
        child: Center(
          child: SizedBox(
            width: width,
            child: ScrollingText(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }

  group('ScrollingText', () {
    testWidgets('does not scroll when text fits', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          text: 'Audio breve',
          width: 360,
        ),
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('uses scrolling container when text overflows', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          text: 'Audio descargado con un título realmente extenso',
        ),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('renders scrolling text golden', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          text: 'Audio descargado con un título realmente extenso',
          width: 200,
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await expectLater(
        find.byType(ScrollingText),
        matchesGoldenFile('goldens/scrolling_text_long.png'),
      );
    });
  });
}
