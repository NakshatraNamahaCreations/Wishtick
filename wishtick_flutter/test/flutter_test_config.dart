import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Suite-wide setup. Flutter runs this around every test file under `test/`.
///
/// Declares reduced motion for the whole suite. That is not cosmetic: the
/// swipe button's sheen repeats forever, and a perpetually scheduled frame
/// means `pumpAndSettle` never sees the tree settle and times out. Gating the
/// shimmer on `MediaQuery.disableAnimations` is the right behaviour for
/// motion-sensitive users anyway, and it makes the whole suite deterministic
/// without every test having to know the button exists.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The SDK's own fake, rather than a hand-rolled implements clause:
  // AccessibilityFeatures gains getters between releases, and implementing it
  // here would break the suite on every such addition.
  TestWidgetsFlutterBinding
      .instance
      .platformDispatcher
      .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
    disableAnimations: true,
    reduceMotion: true,
  );

  await testMain();
}
