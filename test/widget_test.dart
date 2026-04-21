import 'package:fcd_app/src/app.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows splash on startup', (tester) async {
    final session = SessionController();

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionController>.value(
        value: session,
        child: const FcdApp(),
      ),
    );

    expect(find.text('FCD'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));

    session.dispose();
  });
}
