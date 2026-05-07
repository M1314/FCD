import 'package:fcd_app/src/core/widgets/audio_player_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioPlayerWidget', () {
    testWidgets('has AudioPlayerWidget type available as a smoke test',
        (tester) async {
      // Trivial smoke/compilation test only.
      // This does not pump the widget or verify rendering behavior.
      // A real UI test would need a fake/mocked AudioPlayer platform.
      expect(AudioPlayerWidget, isNotNull);
    });
  });
}
