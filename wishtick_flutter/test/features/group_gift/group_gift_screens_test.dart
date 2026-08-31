import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/gifting/data/gifting_repository.dart';
import 'package:wishtick_flutter/features/gifting/presentation/widgets/celebration_mark.dart';
import 'package:wishtick_flutter/features/group_gift/data/group_gift_repository.dart';
import 'package:wishtick_flutter/features/group_gift/domain/group_gift.dart';
import 'package:wishtick_flutter/features/group_gift/domain/settlement.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/create_group_gift_controller.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/create_group_gift_screen.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_add_item_screen.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_charges_screen.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_created_screen.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_details_screen.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_participants_screen.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_settle_screen.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_summary_screen.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/widgets/group_gift_widgets.dart';
import 'package:wishtick_flutter/features/wishlist/data/product_repository.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/product.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';
import 'package:wishtick_flutter/features/wishmates/presentation/widgets/quick_share_sheet.dart';

import '../../helpers/gifting_fakes.dart';
import '../../helpers/group_gift_fakes.dart';
// Prefixed: wishlist_fakes also exports `buildItem`, which here means a
// *wishlist* item rather than a group-gift line.
import '../../helpers/wishlist_fakes.dart' as wl;
import '../../helpers/wishmates_fakes.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required FakeGroupGiftRepository repo,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [groupGiftRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: theme ?? AppTheme.light, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Regression: `_primeGoal` used to run straight out of build(), which writes
  // provider state mid-build and crashed the screen with "Tried to modify a
  // provider while the widget tree was building" the moment it was opened on a
  // device. No unit test could see it — only rendering the real screen does.
  group('Create Group Gift', () {
    Future<void> pumpCreate(WidgetTester tester, {ThemeData? theme}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupGiftRepositoryProvider.overrideWithValue(
              FakeGroupGiftRepository(),
            ),
            wishlistRepositoryProvider.overrideWithValue(
              wl.FakeWishlistRepository(
                wishlists: [
                  wl.buildWishlist(
                    id: 'wl_1',
                    access: const AccessDecision(
                      canView: true,
                      canComment: true,
                      canGift: true,
                      canManage: false,
                      relationship: 'link_holder',
                      role: null,
                    ),
                  ),
                ],
                items: [
                  wl.buildItem(
                    id: 'item_1',
                    title: 'Michael Kors Women Handbag',
                    amountMinor: kItemMinor,
                  ),
                ],
              ),
            ),
            giftingRepositoryProvider.overrideWithValue(
              FakeGiftingRepository(),
            ),
          ],
          child: MaterialApp(
            theme: theme ?? AppTheme.light,
            home: const CreateGroupGiftScreen(
              wishlistId: 'wl_1',
              itemId: 'item_1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens without throwing and seeds the goal from the price', (
      tester,
    ) async {
      await pumpCreate(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Michael Kors Women Handbag'), findsOneWidget);

      // Asserted on the controller rather than the field: the goal input sits
      // below the fold of a lazy ListView, so it has no element to search.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CreateGroupGiftScreen)),
      );
      expect(
        container.read(createGroupGiftProvider('item_1')).goalAmountMinor,
        kItemMinor,
      );
    });

    testWidgets('renders in dark mode', (tester) async {
      await pumpCreate(tester, theme: AppTheme.dark);
      expect(tester.takeException(), isNull);
    });
  });

  // Regression: the picker's FutureProvider.family was once keyed on a record
  // holding a `Set`. Records compare by field but a Set compares by identity,
  // so every rebuild minted a new provider, refetched, and rebuilt — an
  // endless request loop that on device only stopped when the server began
  // answering 429. The key is a plain String now; this pins that.
  group('Add Another Gift', () {
    testWidgets('searches the catalogue once, not once per rebuild', (
      tester,
    ) async {
      final products = wl.FakeProductRepository()
        ..searchResult = const ProductSearchResult(
          items: [
            NormalizedProduct(
              provider: 'fixture',
              externalId: 'hp-001',
              title: 'Wireless Headphones',
              imageUrls: [],
              productUrl: 'https://example.test/hp',
              affiliateUrl: null,
              description: null,
              listPriceMinor: null,
              amountMinor: 249900,
              currency: 'INR',
              merchant: 'Amazon',
              category: null,
              inStock: true,
            ),
          ],
          page: 1,
          pageSize: 20,
          totalEstimate: 1,
          hasMore: false,
          freshness: ResultFreshness.live,
        );
      final repo = FakeGroupGiftRepository(gift: buildGroupGift());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupGiftRepositoryProvider.overrideWithValue(repo),
            productRepositoryProvider.overrideWithValue(products),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const GroupGiftAddItemScreen(groupGiftId: 'gg_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(products.searchCalls, 1);
      expect(find.text('Wireless Headphones'), findsOneWidget);
      // The screen names the group it is adding to (`4007:720`).
      expect(find.textContaining("Siya's birthday gift"), findsOneWidget);

      // A rebuild that does not change the query must not search again.
      await tester.pump();
      expect(products.searchCalls, 1);
    });

    testWidgets('adding sends the provider and external id', (tester) async {
      // A phone-shaped surface: the grid card's `+` sits below the 800x600
      // default, so a tap would land off-screen.
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final products = wl.FakeProductRepository()
        ..searchResult = const ProductSearchResult(
          items: [
            NormalizedProduct(
              provider: 'fixture',
              externalId: 'hp-001',
              title: 'Wireless Headphones',
              imageUrls: [],
              productUrl: 'https://example.test/hp',
              affiliateUrl: null,
              description: null,
              listPriceMinor: null,
              amountMinor: 249900,
              currency: 'INR',
              merchant: null,
              category: null,
              inStock: true,
            ),
          ],
          page: 1,
          pageSize: 20,
          totalEstimate: 1,
          hasMore: false,
          freshness: ResultFreshness.live,
        );
      final repo = FakeGroupGiftRepository(gift: buildGroupGift());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupGiftRepositoryProvider.overrideWithValue(repo),
            productRepositoryProvider.overrideWithValue(products),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const GroupGiftAddItemScreen(groupGiftId: 'gg_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('addGiftLineFromProduct:fixture/hp-001'));
    });

    testWidgets('an unpriced product cannot be added', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final products = wl.FakeProductRepository()
        ..searchResult = const ProductSearchResult(
          items: [
            NormalizedProduct(
              provider: 'fixture',
              externalId: 'no-price',
              title: 'Mystery Box',
              imageUrls: [],
              productUrl: 'https://example.test/mb',
              affiliateUrl: null,
              description: null,
              listPriceMinor: null,
              // The Grand Total is the sum of the gifts; an unpriced line
              // would silently add nothing to it.
              amountMinor: null,
              currency: 'INR',
              merchant: null,
              category: null,
              inStock: true,
            ),
          ],
          page: 1,
          pageSize: 20,
          totalEstimate: 1,
          hasMore: false,
          freshness: ResultFreshness.live,
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupGiftRepositoryProvider.overrideWithValue(
              FakeGroupGiftRepository(gift: buildGroupGift()),
            ),
            productRepositoryProvider.overrideWithValue(products),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const GroupGiftAddItemScreen(groupGiftId: 'gg_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(find.byType(IconButton).last);
      expect(button.onPressed, isNull);
    });
  });

  // Regression: AmountChip used a Container with an `alignment`, which expands
  // to the maximum *bounded* constraint. Inside a Wrap that is the full row
  // width, so all three chips came out full-bleed and stacked one per line
  // instead of sitting side by side as `299:1658` and `316:119` draw them.
  testWidgets('suggested-amount chips sit on one row, not stacked', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SizedBox(
            width: 393,
            child: Wrap(
              spacing: AppSpacing.md,
              children: [
                AmountChip(amountMinor: 50000),
                AmountChip(amountMinor: 100000),
                AmountChip(amountMinor: 200000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chips = tester
        .widgetList<AmountChip>(find.byType(AmountChip))
        .toList();
    expect(chips, hasLength(3));

    final boxes = find
        .byType(AmountChip)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    // All three share a top edge — i.e. one run, not three.
    expect(boxes.every((r) => r.top == boxes.first.top), isTrue);
    // And none of them is full-bleed.
    expect(boxes.every((r) => r.width < 200), isTrue);
  });

  group('Group Gift Summary', () {
    testWidgets('the × appears on extra gifts only, never the primary', (
      tester,
    ) async {
      final gift = buildGroupGift(
        items: [
          buildItem(),
          buildItem(
            itemId: 'item_2',
            lineId: 'line_2',
            title: 'Apple AirPods Pro',
            amountMinor: 2490000,
          ),
        ],
      );
      final repo = FakeGroupGiftRepository(gift: gift);

      await pump(
        tester,
        GroupGiftSummaryScreen(groupGiftId: 'gg_1', initial: gift),
        repo: repo,
      );

      expect(find.text('Selected Gifts (2)'), findsOneWidget);
      // Dropping the primary would leave a group gift for nothing; the design
      // offers cancel for that instead.
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('the cost breakdown only appears once there is a charge', (
      tester,
    ) async {
      final bare = buildGroupGift(targetAmountMinor: kItemMinor);
      await pump(
        tester,
        GroupGiftSummaryScreen(groupGiftId: 'gg_1', initial: bare),
        repo: FakeGroupGiftRepository(gift: bare),
      );
      expect(find.text('Grand Total'), findsNothing);

      final billed = buildGroupGift(
        chargesTotalMinor: kDeliveryMinor + kPackagingMinor,
        charges: [
          buildCharge(),
          buildCharge(
            id: 'c2',
            label: 'Packaging',
            amountMinor: kPackagingMinor,
          ),
        ],
      );
      await pump(
        tester,
        GroupGiftSummaryScreen(groupGiftId: 'gg_2', initial: billed),
        repo: FakeGroupGiftRepository(gift: billed),
      );

      expect(find.text('Total Gift Price'), findsOneWidget);
      // The design's own arithmetic: ₹16,999 + ₹199 + ₹149.
      expect(find.text('₹17,347'), findsOneWidget);
      expect(find.text('₹16,999'), findsWidgets);
    });
  });

  group('Settle Up picks its state from the balance', () {
    GroupGiftBalance balanceOf(int differenceMinor) => GroupGiftBalance(
      totalCostMinor: kGrandTotalMinor,
      pledgedMinor: kGrandTotalMinor + differenceMinor,
      collectedMinor: kGrandTotalMinor + differenceMinor,
      differenceMinor: differenceMinor,
      direction: differenceMinor > 0
          ? SettlementDirection.returnToContributors
          : differenceMinor < 0
          ? SettlementDirection.topUp
          : null,
      contributorCount: 6,
    );

    testWidgets('a surplus asks how to hand it back', (tester) async {
      await pump(
        tester,
        const GroupGiftSettleScreen(groupGiftId: 'gg_1'),
        repo: FakeGroupGiftRepository(stubBalance: balanceOf(200000)),
      );

      expect(find.text('Refund Distribution'), findsOneWidget);
      expect(find.text('Extra Balance'), findsOneWidget);
      // ₹2,000 across 6 people.
      expect(find.text('Every one gets ₹333'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('a shortfall asks the group for more', (tester) async {
      await pump(
        tester,
        const GroupGiftSettleScreen(groupGiftId: 'gg_1'),
        repo: FakeGroupGiftRepository(stubBalance: balanceOf(-200000)),
      );

      expect(find.text('Contribution Request'), findsOneWidget);
      expect(find.text('Additional Amount Required'), findsWidgets);
      expect(find.text('Send Request'), findsOneWidget);
    });

    testWidgets('square says so rather than offering an empty form', (
      tester,
    ) async {
      await pump(
        tester,
        const GroupGiftSettleScreen(groupGiftId: 'gg_1'),
        repo: FakeGroupGiftRepository(stubBalance: balanceOf(0)),
      );

      expect(find.text('Everyone is square.'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('an existing ledger shows progress, not the setup form', (
      tester,
    ) async {
      await pump(
        tester,
        const GroupGiftSettleScreen(groupGiftId: 'gg_1'),
        repo: FakeGroupGiftRepository(
          stubBalance: balanceOf(200000),
          settlements: [
            buildSettlement(),
            buildSettlement(id: 'st_2'),
          ],
        ),
      );

      expect(find.text('Refund Progress'), findsOneWidget);
      expect(find.text('Contributors (2)'), findsOneWidget);
      expect(find.text('Refund Distribution'), findsNothing);
    });

    testWidgets('a row with no UPI ID yet cannot be marked sent', (
      tester,
    ) async {
      await pump(
        tester,
        const GroupGiftSettleScreen(groupGiftId: 'gg_1'),
        repo: FakeGroupGiftRepository(
          stubBalance: balanceOf(200000),
          settlements: [buildSettlement()],
        ),
      );

      // No session in this harness, so the viewer is neither party and gets the
      // receiver's affordance — the point is that "Mark as Sent" is not
      // offered while there is nowhere to send it.
      expect(find.text('Mark as Sent'), findsNothing);
    });
  });

  // "This should be in instagram share format and bottomsheet should be
  // minimum." Both invite buttons open the same quick-share sheet the wishlist
  // and event share buttons use — a grid of faces, tap to pick, one send —
  // rather than a full-height list of rows.
  group('inviting WishMates to chip in', () {
    late FakeWishmatesRepository mates;

    setUp(
      () => mates = FakeWishmatesRepository(
        mates: [
          buildWishmate(userId: 'u_1', displayName: 'Priyal Sharma'),
          buildWishmate(userId: 'u_2', displayName: 'Rohan Prasad'),
        ],
      ),
    );

    Future<void> pumpScreen(
      WidgetTester tester,
      Widget screen,
      FakeGroupGiftRepository repo,
    ) async {
      tester.view
        ..physicalSize = const Size(393, 1400)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            groupGiftRepositoryProvider.overrideWithValue(repo),
            wishmatesRepositoryProvider.overrideWithValue(mates),
          ],
          child: MaterialApp(theme: AppTheme.light, home: screen),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the created screen opens the quick-share grid', (
      tester,
    ) async {
      final repo = FakeGroupGiftRepository(gift: buildGroupGift())
        ..inviteResult = (invited: 1, skipped: 0);
      await pumpScreen(
        tester,
        const GroupGiftCreatedScreen(groupGiftId: 'gg_1'),
        repo,
      );

      await tester.tap(find.text('Invite Friends'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickShareSheet), findsOneWidget);
      expect(find.text('Priyal Sharma'), findsOneWidget);
    });

    // The bug that started this: the participants screen was still copying a
    // link long after the created screen had stopped.
    testWidgets('the participants screen opens it too, and sends', (
      tester,
    ) async {
      final repo = FakeGroupGiftRepository(gift: buildGroupGift())
        ..inviteResult = (invited: 1, skipped: 0);
      await pumpScreen(
        tester,
        const GroupGiftParticipantsScreen(groupGiftId: 'gg_1'),
        repo,
      );

      await tester.tap(find.text('Invite Friends & Family'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickShareSheet), findsOneWidget);

      await tester.tap(find.text('Priyal Sharma'));
      await tester.pump();
      await tester.tap(find.textContaining('Send to'));
      await tester.pumpAndSettle();

      expect(repo.invitedUserIds, [
        ['u_1'],
      ]);
    });

    // The sheet is sized to what is in it. Two WishMates must not open half a
    // screen of nothing under one row of faces.
    testWidgets('the sheet is no taller than its contents', (tester) async {
      final repo = FakeGroupGiftRepository(gift: buildGroupGift());
      await pumpScreen(
        tester,
        const GroupGiftParticipantsScreen(groupGiftId: 'gg_1'),
        repo,
      );

      await tester.tap(find.text('Invite Friends & Family'));
      await tester.pumpAndSettle();

      final sheet = tester.getSize(find.byType(QuickShareSheet));
      // Well under the 85% cap it is allowed to grow to, and under half the
      // screen: two faces is one row.
      expect(sheet.height, lessThan(1400 * 0.5));
    });

    // The server skips who it cannot invite rather than failing the batch, so
    // "Invite sent to 2 WishMates" over one real invitation is reachable
    // without any error to catch.
    testWidgets('does not claim a send for people the server skipped', (
      tester,
    ) async {
      final repo = FakeGroupGiftRepository(gift: buildGroupGift())
        ..inviteResult = (invited: 0, skipped: 1);
      await pumpScreen(
        tester,
        const GroupGiftParticipantsScreen(groupGiftId: 'gg_1'),
        repo,
      );

      await tester.tap(find.text('Invite Friends & Family'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Priyal Sharma'));
      await tester.pump();
      await tester.tap(find.textContaining('Send to'));
      await tester.pumpAndSettle();

      expect(find.text('Some of them already had access.'), findsOneWidget);
      expect(find.textContaining('Invite sent'), findsNothing);
    });

    testWidgets('counts only what actually went out', (tester) async {
      final repo = FakeGroupGiftRepository(gift: buildGroupGift())
        ..inviteResult = (invited: 1, skipped: 1);
      await pumpScreen(
        tester,
        const GroupGiftParticipantsScreen(groupGiftId: 'gg_1'),
        repo,
      );

      await tester.tap(find.text('Invite Friends & Family'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Priyal Sharma'));
      await tester.pump();
      await tester.tap(find.text('Rohan Prasad'));
      await tester.pump();
      await tester.tap(find.textContaining('Send to'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Two picked, one invited. The dialog must say one — asserted
      // positively, because two findsNothing would also pass if no
      // confirmation appeared at all.
      expect(find.text('Invite sent'), findsOneWidget);
      expect(find.textContaining('2 WishMates'), findsNothing);
    });

    // The share block is the host's alone, so gating on it left every other
    // member looking at a dead button. Any member may invite.
    // The other three "you did it" screens burst; this one used to be a still
    // icon, which made the only screen that is purely a celebration the flat
    // one.
    testWidgets('the created screen celebrates', (tester) async {
      await pumpScreen(
        tester,
        const GroupGiftCreatedScreen(groupGiftId: 'gg_1'),
        FakeGroupGiftRepository(gift: buildGroupGift()),
      );
      expect(find.byType(CelebrationMark), findsOneWidget);
    });

    testWidgets('a member with no share link can still invite', (tester) async {
      await pumpScreen(
        tester,
        const GroupGiftParticipantsScreen(groupGiftId: 'gg_1'),
        FakeGroupGiftRepository(gift: buildGroupGift()),
      );

      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Invite Friends & Family'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  // Every screen, both themes. Short of a device this is the standing check
  // that the sprint's "verified in light and dark" rule is actually met — and
  // it is what caught the infinite-width button in the settle ledger.
  group('renders in both themes', () {
    final gift = buildGroupGift(
      chargesTotalMinor: kDeliveryMinor,
      charges: [buildCharge()],
      participants: const [
        GroupGiftParticipant(userId: 'host_1', name: 'Rohan'),
        GroupGiftParticipant(userId: 'user_2', name: 'Sona'),
      ],
      share: const GroupGiftShare(
        slug: 'abc',
        url: 'https://wishtick.test/g/abc',
        hasPasscode: false,
      ),
    );

    final screens = <String, Widget>{
      'summary': GroupGiftSummaryScreen(groupGiftId: 'gg_1', initial: gift),
      'charges': const GroupGiftChargesScreen(groupGiftId: 'gg_1'),
      'details': const GroupGiftDetailsScreen(groupGiftId: 'gg_1'),
      'participants': const GroupGiftParticipantsScreen(groupGiftId: 'gg_1'),
      'created': const GroupGiftCreatedScreen(groupGiftId: 'gg_1'),
      'settle': const GroupGiftSettleScreen(groupGiftId: 'gg_1'),
    };

    for (final theme in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      for (final screen in screens.entries) {
        testWidgets('${screen.key} — ${theme.key}', (tester) async {
          await pump(
            tester,
            screen.value,
            repo: FakeGroupGiftRepository(
              gift: gift,
              stubBalance: const GroupGiftBalance(
                totalCostMinor: kGrandTotalMinor,
                pledgedMinor: kGrandTotalMinor + 200000,
                collectedMinor: kGrandTotalMinor + 200000,
                differenceMinor: 200000,
                direction: SettlementDirection.returnToContributors,
                contributorCount: 6,
              ),
            ),
            theme: theme.value,
          );

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
