import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/widgets/choose_wishlist_sheet.dart';

import '../../../helpers/load_app_fonts.dart';
import '../../../helpers/wishlist_fakes.dart';

void main() {
  // Real glyph widths: Ahem's full-em squares make the collapsed sheet look
  // nearly full-width, which would hide most of this bug.
  setUpAll(loadAppFonts);

  const surface = Size(400, 900);

  Future<void> open(WidgetTester tester, List<Wishlist> options) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    ChooseWishlistSheet.show(context, options: options),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Regression: the sheet used to collapse to the width of its title when
  /// there was nothing to list, because a modal sheet constrains its child
  /// loosely and the Column was min-sized.
  testWidgets('fills the screen width with no wishlists to show', (
    tester,
  ) async {
    await open(tester, const []);

    expect(find.text('No other wishlists yet.'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ChooseWishlistSheet)).width,
      surface.width,
    );
  });

  testWidgets('is the same width once there are wishlists', (tester) async {
    await open(tester, [buildWishlist(title: 'Birthday')]);

    expect(find.text('Birthday'), findsOneWidget);
    expect(
      tester.getSize(find.byType(ChooseWishlistSheet)).width,
      surface.width,
    );
  });

  testWidgets('returns the tapped wishlist', (tester) async {
    await open(tester, [buildWishlist(id: 'wl_9', title: 'Birthday')]);

    await tester.tap(find.text('Birthday'));
    await tester.pumpAndSettle();

    expect(find.byType(ChooseWishlistSheet), findsNothing);
  });
}
