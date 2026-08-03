import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/dev/dev_taxonomy.dart';

/// Pins `assets/onboarding/<key>.png` existing for every top-level interest
/// category.
///
/// [PhotoTileGrid]'s `errorBuilder` swallows a missing asset into a themed
/// placeholder silently — exactly the failure mode that would hide a typo'd
/// key or a forgotten `pubspec.yaml` registration, so this checks the real
/// files on disk rather than trusting the fallback to look "fine".
void main() {
  test('every interest category has exported tile artwork', () {
    final categories = DevTaxonomy.build().interestCategories;
    expect(categories, hasLength(12));

    for (final category in categories) {
      final file = File('assets/onboarding/${category.key}.png');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'missing assets/onboarding/${category.key}.png',
      );
    }
  });
}
