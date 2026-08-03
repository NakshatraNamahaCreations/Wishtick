import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the brand mark files existing on disk under the paths the splash
/// screen and onboarding progress header reference directly.
///
/// `Image.asset`'s error path renders nothing but doesn't throw synchronously
/// in a widget test, so a missing file or a forgotten `pubspec.yaml`
/// registration would otherwise fail silently rather than as a clear test.
void main() {
  test('both logo marks exist where the app expects them', () {
    for (final path in ['assets/logo/logo.png', 'assets/logo/logo_small.png']) {
      expect(File(path).existsSync(), isTrue, reason: 'missing $path');
    }
  });
}
