import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/gifting/presentation/widgets/celebration_mark.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/added_to_wishlist_screen.dart';

/// Figma `288:721` — the confetti-burst logo mark, not a plain heart icon.
void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: const AddedToWishlistScreen(wishlistTitle: "Ananya's Wishlist"),
    ),
  );

  testWidgets('shows the confetti logo mark, not a plain heart icon', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(CelebrationMark), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName == 'assets/logo/logo.png',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('names the wishlist the item was added to', (tester) async {
    await pump(tester);

    expect(find.text("Added to Ananya's Wishlist"), findsOneWidget);
  });

  testWidgets(
    "the mark's confetti burst box does not push the heading away — only "
    'the logo image itself counts against layout',
    (tester) async {
      await pump(tester);

      // The logo image, not [CelebrationMark]'s own rect: that box is
      // always 240×240 for the confetti burst regardless of how it is laid
      // out, so measuring it can't tell a tight fit from a padded one.
      final logoBottom = tester
          .getRect(
            find.byWidgetPredicate(
              (w) =>
                  w is Image &&
                  (w.image as AssetImage).assetName == 'assets/logo/logo.png',
            ),
          )
          .bottom;
      final headingTop = tester
          .getRect(find.text("Added to Ananya's Wishlist"))
          .top;

      // Without the fix, [CelebrationMark]'s full 240-tall box counts
      // against layout — 60px of empty padding below the 120-tall logo —
      // and the gap balloons past 60.
      expect(headingTop - logoBottom, lessThan(60));
    },
  );
}
