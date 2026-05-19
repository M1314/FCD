import 'package:flutter/foundation.dart';

// Singleton used so overlays can switch the HomeShell tab
// without needing a BuildContext tied to the bottom nav.
class HomeTabController extends ChangeNotifier {
  HomeTabController({int initialIndex = 0}) : _index = initialIndex;

  int _index;

  int get index => _index;

  void setIndex(int index, {bool notify = true}) {
    if (_index == index) {
      return;
    }
    _index = index;
    if (notify) {
      notifyListeners();
    }
  }
}

final HomeTabController homeTabController = HomeTabController();
