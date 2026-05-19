import 'package:flutter/foundation.dart';

// Singleton used so overlays can switch the HomeShell tab
// without needing a BuildContext tied to the bottom nav.
class HomeTabController extends ChangeNotifier {
  HomeTabController({int initialIndex = 0}) : _index = initialIndex;

  int _index;

  int get index => _index;

  void setIndex(int index) {
    if (_index == index) {
      return;
    }
    _index = index;
    notifyListeners();
  }
}

HomeTabController? _homeTabController;

HomeTabController get homeTabController =>
    _homeTabController ??= HomeTabController();

@visibleForTesting
void resetHomeTabController({int initialIndex = 0}) {
  _homeTabController?.dispose();
  _homeTabController = HomeTabController(initialIndex: initialIndex);
}
