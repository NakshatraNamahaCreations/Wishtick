import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/gifting/data/gifting_repository.dart';
import 'package:wishtick_flutter/features/gifting/presentation/gift_item_screen.dart';
import 'package:wishtick_flutter/features/group_gift/data/group_gift_repository.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';

import '../../helpers/gifting_fakes.dart';
// Prefixed: group_gift_fakes also exports buildItem, which there means a
// group-gift line rather than a wishlist item.
import '../../helpers/group_gift_fakes.dart' as gg;
import '../../helpers/wishlist_fakes.dart';

/// An item a group is already collecting for.
///
/// The server refuses all three of Reserve, Gift Now and Start a Group Gift
/// once an item is claimed — each with a 409 — so offering them is offering
/// three dead ends. The only honest thing on the screen is a way into the
/// group that already exists.
void main() {
  Future<void> pump(
    WidgetTester tester,
    gg.FakeGroupGiftRepository groupGifts, {
    ThemeData? theme,
  }) async {
    // Wider than a phone on purpose. SummaryRow in product_detail_body puts an
    // unconstrained label, a Spacer and the value in one Row, so the fakes'
    // longer strings overflow it at 393 — a separate pre-existing bug, and not
    // what this file is about.
    tester.view
      ..physicalSize = const Size(700, 1600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/item',
      routes: [
        GoRoute(
          path: '/item',
          builder: (_, _) =>
              const GiftItemScreen(wishlistId: 'wl_1', itemId: 'item_1'),
        ),
        GoRoute(
          path: '/group-gifts/:id',
          builder: (_, state) =>
              Scaffold(body: Text('group ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          wishlistRepositoryProvider.overrideWithValue(
            FakeWishlistRepository(
              wishlists: [buildWishlist(id: 'wl_1', access: sharedAccess)],
              items: [buildItem(id: 'item_1')],
            ),
          ),
          giftingRepositoryProvider.overrideWithValue(FakeGiftingRepository()),
          groupGiftRepositoryProvider.overrideWithValue(groupGifts),
        ],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers the running group instead of three dead buttons', (
    tester,
  ) async {
    await pump(
      tester,
      gg.FakeGroupGiftRepository()..itemGroupGift = gg.buildItemGroupGift(),
    );

    expect(find.text('A group gift is already running'), findsOneWidget);
    expect(find.text('View group gift'), findsOneWidget);
    // Every one of these would be refused by the server.
    expect(find.text('Reserve Gift'), findsNothing);
    expect(find.text('Gift Now'), findsNothing);
    expect(find.text('Start a Group Gift'), findsNothing);
  });

  testWidgets('says how far along the collection is', (tester) async {
    await pump(
      tester,
      gg.FakeGroupGiftRepository()
        ..itemGroupGift = gg.buildItemGroupGift(
          targetAmountMinor: 487100,
          collectedAmountMinor: 200000,
          contributorCount: 3,
        ),
    );

    expect(
      find.text('₹2,000 of ₹4,871 collected · 3 people chipping in'),
      findsOneWidget,
    );
  });

  // "0 people chipping in" reads as a failed collection rather than a fresh
  // one nobody has reached yet.
  testWidgets('drops the contributor line before anyone has chipped in', (
    tester,
  ) async {
    await pump(
      tester,
      gg.FakeGroupGiftRepository()
        ..itemGroupGift = gg.buildItemGroupGift(
          collectedAmountMinor: 0,
          contributorCount: 0,
        ),
    );

    expect(find.text('₹0 of ₹4,871 collected'), findsOneWidget);
    expect(find.textContaining('0 people'), findsNothing);
  });

  testWidgets('opens the group it names', (tester) async {
    await pump(
      tester,
      gg.FakeGroupGiftRepository()
        ..itemGroupGift = gg.buildItemGroupGift(id: 'gg_42'),
    );

    await tester.tap(find.text('View group gift'));
    await tester.pumpAndSettle();

    expect(find.text('group gg_42'), findsOneWidget);
  });

  // The ordinary case: nothing collecting, so the item keeps all three CTAs.
  testWidgets('leaves an unclaimed item alone', (tester) async {
    await pump(tester, gg.FakeGroupGiftRepository()..itemGroupGift = null);

    expect(find.text('A group gift is already running'), findsNothing);
    expect(find.text('Reserve Gift'), findsOneWidget);
    expect(find.text('Gift Now'), findsOneWidget);
    expect(find.text('Start a Group Gift'), findsOneWidget);
  });

  testWidgets('renders on a dark page', (tester) async {
    await pump(
      tester,
      gg.FakeGroupGiftRepository()..itemGroupGift = gg.buildItemGroupGift(),
      theme: AppTheme.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('View group gift'), findsOneWidget);
  });
}
