import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_palette.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist_item.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/save_to_wishlist_screen.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/widgets/pick_tile.dart';

import '../../helpers/wishlist_fakes.dart';

/// Saving a product to a chosen wishlist.
///
/// The list is picked before this screen opens and already carries who it is
/// for and what the occasion is, so the screen no longer asks for either —
/// it inherits them.
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

  /// The same screen, with a repository to assert on.
  ///
  /// Seeded with the list being saved into: the screen refreshes it once the
  /// item is in, and a fake that has never heard of it throws mid-save.
  Future<FakeWishlistRepository> pumpWith(
    WidgetTester tester,
    Wishlist wishlist,
  ) async {
    final repo = FakeWishlistRepository(wishlists: [wishlist]);
    tester.view
      ..physicalSize = const Size(393, 2000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wishlistRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: SaveToWishlistScreen(
            wishlist: wishlist,
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
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  /// Saves, and hands back what the item was created with.
  Future<WishlistItem> save(
    WidgetTester tester,
    FakeWishlistRepository r,
  ) async {
    // The button, not the app bar title, which says the same words.
    final button = find.widgetWithText(ElevatedButton, 'Save to Wishlist');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    return r.items.last;
  }

  testWidgets('does not ask again for what the wishlist already knows', (
    tester,
  ) async {
    await pump(tester);

    // The list is chosen before this screen opens, and it carries both.
    expect(find.text('Who is this gift for?'), findsNothing);
    expect(find.text("What's the occasion?"), findsNothing);
    expect(find.byType(PickTile), findsNothing);
    expect(find.widgetWithText(TextField, "Person's Name *"), findsNothing);
    expect(find.widgetWithText(TextField, 'Relation *'), findsNothing);
  });

  // Not asking is not the same as not recording: the item still carries who
  // and what for, taken from the list rather than typed a second time.
  testWidgets('inherits the recipient and occasion from the wishlist', (
    tester,
  ) async {
    final repo = await pumpWith(
      tester,
      buildWishlist(title: 'Siya Kapoor', occasionLabel: 'Birthday'),
    );

    final item = await save(tester, repo);

    expect(item.recipientName, 'Siya Kapoor');
    expect(item.occasionKey, 'birthday');
  });

  // Free text the taxonomy has never heard of is a fine occasion for a list,
  // and a fine thing for an item to carry no key for.
  testWidgets('carries no occasion key when the list has free text', (
    tester,
  ) async {
    final repo = await pumpWith(
      tester,
      buildWishlist(title: 'Siya', occasionLabel: 'Passed the bar'),
    );

    final item = await save(tester, repo);

    expect(item.recipientName, 'Siya');
    expect(item.occasionKey, isNull);
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
