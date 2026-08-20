import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_palette.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/save_to_wishlist_screen.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/widgets/pick_tile.dart';

import '../../helpers/wishlist_fakes.dart';

/// Figma `280:584` — the occasion picker is 8 photo tiles, not icons.
void main() {
  Widget screen() => ProviderScope(
    overrides: [
      wishlistRepositoryProvider.overrideWithValue(FakeWishlistRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: SaveToWishlistScreen(
        wishlist: buildWishlist(),
        productTitle: 'Nike Air Max Sneakers',
        productSubtitle: null,
        productImageUrl: null,
        amountMinor: 1099900,
        productUrl: 'https://example.com/product',
        category: null,
        provider: null,
        externalId: null,
      ),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 2000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen());
  }

  const expectedImages = {
    'Birthday': 'assets/images/Celebrations_images/Birthday.png',
    'Anniversary': 'assets/images/Celebrations_images/Anniversary.png',
    'Wedding': 'assets/images/Celebrations_images/Wedding.png',
    'Housewarming': 'assets/images/Celebrations_images/House_Warming.png',
    'Baby Shower': 'assets/images/Celebrations_images/Mom_to_Be.png',
    'Special Moments': 'assets/images/Celebrations_images/Best_Wishes.png',
    'Festival': 'assets/images/Celebrations_images/Rakhi.png',
    'Just Because': 'assets/images/Celebrations_images/Just_Because.png',
  };

  testWidgets('every occasion tile is a photo, not an icon', (tester) async {
    await pump(tester);

    for (final entry in expectedImages.entries) {
      expect(
        find.byWidgetPredicate(
          (w) => w is Image && (w.image as AssetImage).assetName == entry.value,
        ),
        findsOneWidget,
        reason: '${entry.key} should render ${entry.value}',
      );
    }
    expect(find.byType(PickTile), findsNWidgets(expectedImages.length));
    // No PickTile renders an Icon — the screen's other icons (importance
    // rows) are outside this widget entirely.
    for (final tile in tester.widgetList<PickTile>(find.byType(PickTile))) {
      expect(tile.icon, isNull);
    }
  });

  testWidgets('tapping an occasion tile selects it', (tester) async {
    await pump(tester);

    await tester.ensureVisible(find.text('Birthday'));
    await tester.tap(find.text('Birthday'));
    await tester.pump();

    final tile = tester.widget<PickTile>(
      find.ancestor(of: find.text('Birthday'), matching: find.byType(PickTile)),
    );
    expect(tile.selected, isTrue);
  });

  testWidgets('tapping a quick suggestion chip fills the note field', (
    tester,
  ) async {
    await pump(tester);

    await tester.ensureVisible(find.text('Perfect for her'));
    await tester.tap(find.text('Perfect for her'));
    await tester.pump();

    expect(find.text('Perfect for her'), findsNWidgets(2));
  });

  testWidgets(
    'quick suggestion chips use the translucent suggestion-chip fill and '
    'plumSoft ink, matching the reference exactly',
    (tester) async {
      await pump(tester);

      await tester.ensureVisible(find.text('Perfect for her'));
      final chip = tester.widget<ActionChip>(
        find.ancestor(
          of: find.text('Perfect for her'),
          matching: find.byType(ActionChip),
        ),
      );

      expect(chip.backgroundColor, AppPalette.suggestionChipFill);
      expect(chip.backgroundColor, const Color(0xEBE9DBED));
      expect(chip.labelStyle?.color, AppPalette.plumSoft);
      expect(chip.labelStyle?.color, const Color(0xFF7B3A8F));
    },
  );
}
