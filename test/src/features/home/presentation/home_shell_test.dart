import 'package:fcd_app/src/features/downloads/data/repositories/download_repository.dart';
import 'package:fcd_app/src/features/downloads/presentation/download_task_controller.dart';
import 'package:fcd_app/src/features/home/presentation/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../test_helpers/fake_api_client.dart';

void main() {
  testWidgets(
    'reselecting current destination scrolls that tab to top',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<DownloadTaskController>(
          create: (_) => DownloadTaskController(
            downloadRepository: DownloadRepository(apiClient: FakeApiClient()),
          ),
          child: MaterialApp(
            home: HomeShell(
              pages: List<Widget>.generate(
                6,
                (index) => _ScrollableTestPage(index: index),
              ),
            ),
          ),
        ),
      );

      tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      ).onDestinationSelected?.call(1);
      await tester.pumpAndSettle();

      await tester.drag(find.byKey(const ValueKey<String>('list-1')), const Offset(0, -500));
      await tester.pumpAndSettle();

      final scrolledPosition = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('page-1')),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels;
      expect(scrolledPosition, greaterThan(0));

      tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      ).onDestinationSelected?.call(1);
      await tester.pumpAndSettle();

      final resetPosition = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('page-1')),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .pixels;
      expect(resetPosition, 0);
    },
  );
}

class _ScrollableTestPage extends StatelessWidget {
  const _ScrollableTestPage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<String>('page-$index'),
      child: ListView.builder(
        key: ValueKey<String>('list-$index'),
        itemCount: 60,
        itemBuilder: (context, itemIndex) {
          return SizedBox(
            height: 60,
            child: Text('Página $index - item $itemIndex'),
          );
        },
      ),
    );
  }
}
