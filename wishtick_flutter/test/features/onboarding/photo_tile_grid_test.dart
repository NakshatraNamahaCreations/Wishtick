import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/onboarding/domain/onboarding_options.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/widgets/photo_tile_grid.dart';

import '../../helpers/load_app_fonts.dart';

/// Regression test for the interest-tile photos rendering at different
/// heights depending on their label — one screenshot showed "Automotive"
/// (one line) with a visibly taller photo than "Fashion & Personal Style"
/// (two lines), even though every grid cell is the same bounding box.
///
/// Real fonts are required here, not just convention: the default test font
/// inflates glyph width, which changes exactly which labels wrap to one line
/// versus two — the one variable this bug depends on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  testWidgets(
    'tile photos are the same height whether the label wraps one line or two',
    (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const options = [
        TaxonomyOption(key: 'automotive', label: 'Automotive'),
        TaxonomyOption(key: 'fashion', label: 'Fashion & Personal Style'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PhotoTileGrid(
              options: options,
              selectedKeys: const {},
              onToggle: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sanity check that the labels actually wrap differently under a real
      // font — otherwise this test would pass for the wrong reason.
      expect(
        tester.getRect(find.text('Automotive')).height,
        lessThan(tester.getRect(find.text('Fashion & Personal Style')).height),
        reason: 'the two labels must actually differ in line count',
      );

      Rect photoRectFor(String label) => tester.getRect(
        find.descendant(
          of: find.ancestor(
            of: find.text(label),
            matching: find.byType(PhotoTile),
          ),
          matching: find.byType(ClipRRect),
        ),
      );

      final oneLinePhoto = photoRectFor('Automotive');
      final twoLinePhoto = photoRectFor('Fashion & Personal Style');

      expect(
        oneLinePhoto.height,
        moreOrLessEquals(twoLinePhoto.height, epsilon: 1),
        reason:
            'a one-line label must not leave its photo taller than a '
            "tile whose label wraps to two lines — every tile's photo box "
            'should be identical',
      );
    },
  );
}
