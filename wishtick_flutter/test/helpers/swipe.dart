import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_swipe_button.dart';

/// Drags the swipe-to-continue track all the way across and settles.
///
/// The offset is deliberately larger than any track in the app: the knob
/// clamps at the end of its travel, so a test never has to know how wide the
/// pill is on the screen it happens to be driving. Anything past 75% of the
/// travel commits, so this is comfortably a completed swipe.
Future<void> swipeToContinue(WidgetTester tester, [Finder? track]) async {
  final target = (track ?? find.byType(WishtickSwipeButton)).first;
  await tester.drag(target, const Offset(500, 0));
  await _drainCommit(tester);
}

/// Advances fake time in fixed steps rather than relying solely on
/// [WidgetTester.pumpAndSettle].
///
/// A completed swipe passes through stretches with no active animation — the
/// repository call, the success-check dwell — where nothing is scheduled to
/// redraw. `pumpAndSettle` bails out the moment it sees no scheduled frame, so
/// it can return *before* those bare `Future.delayed` timers ever fire,
/// silently skipping the success check and the navigation that follows it.
/// Twenty 100ms steps comfortably covers collapse (250ms) + the widest fake
/// repository latency (~400ms) + the dwell (500ms) + the reset (250ms).
Future<void> _drainCommit(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// A drag that stops short of the commit threshold, to prove the control
/// springs back rather than submitting.
Future<void> swipePartway(WidgetTester tester, [Finder? track]) async {
  final target = (track ?? find.byType(WishtickSwipeButton)).first;
  await tester.drag(target, const Offset(40, 0));
  await tester.pumpAndSettle();
}
