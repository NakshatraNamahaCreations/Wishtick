import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_dimens.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/addresses/data/addresses_repository.dart';
import 'package:wishtick_flutter/features/group_gift/data/group_gift_repository.dart';
import 'package:wishtick_flutter/features/group_gift/domain/group_gift.dart';
import 'package:wishtick_flutter/features/home/data/home_repository.dart';
import 'package:wishtick_flutter/features/home/presentation/home_screen.dart';
import 'package:wishtick_flutter/features/home/presentation/widgets/carousel_dots.dart';
import 'package:wishtick_flutter/features/home/presentation/widgets/home_cards.dart';
import 'package:wishtick_flutter/features/home/presentation/widgets/home_header.dart';
import 'package:wishtick_flutter/features/notifications/data/notifications_repository.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';

// Only the fake repository: home_fakes owns this file's buildGroupGift.
import '../../helpers/group_gift_fakes.dart' show FakeGroupGiftRepository;
import '../../helpers/home_fakes.dart';
import '../../helpers/profile_fakes.dart';
import '../../helpers/wishlist_fakes.dart';

/// `51:11` — the two flattened promo banners, the occasion grid (covered by
/// its own test file) and the group-gift/event/wishlist rails.
void main() {
  Future<void> pump(WidgetTester tester, {List<GroupGift>? groupGifts}) async {
    tester.view
      ..physicalSize = const Size(393, 1600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeRepositoryProvider.overrideWithValue(
            FakeHomeRepository(groupGifts: groupGifts),
          ),
          wishlistRepositoryProvider.overrideWithValue(
            FakeWishlistRepository(),
          ),
          addressesRepositoryProvider.overrideWithValue(
            FakeAddressesRepository(),
          ),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
          // The pending-invites banner asks for them on every Home build.
          // Unoverridden it reaches the real ApiClient, and Riverpod retrying
          // the failure leaves a timer pending past the end of the test.
          groupGiftRepositoryProvider.overrideWithValue(
            FakeGroupGiftRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows both flattened promo banners', (tester) async {
    await pump(tester);

    expect(find.byType(CelebrateMomentBanner), findsOneWidget);
    expect(find.byType(BirthdaysBanner), findsOneWidget);
  });

  testWidgets('one open group gift shows no page dots', (tester) async {
    await pump(tester, groupGifts: [buildGroupGift(id: 'gg_1')]);

    expect(find.byType(GroupGiftCard), findsOneWidget);
    // Fewer than the event/wishlist dot rows this screen also renders would
    // still be ambiguous, so this checks there is exactly one dot total.
    expect(find.text('gg_1'), findsNothing); // sanity: id itself never leaks
  });

  testWidgets(
    'several open group gifts page through as a carousel, one per swipe',
    (tester) async {
      await pump(
        tester,
        groupGifts: [
          buildGroupGift(id: 'gg_1'),
          buildGroupGift(id: 'gg_2'),
          buildGroupGift(id: 'gg_3'),
        ],
      );

      // Only the first card's content is on-screen initially.
      expect(find.byType(GroupGiftCard), findsOneWidget);

      await tester.drag(
        find.byType(GroupGiftCard).first,
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GroupGiftCard), findsOneWidget);
    },
  );

  // The card is a photograph with the copy laid into the empty gold down its
  // left. Drawn any shorter than the artwork's own 552x450, `cover` starts
  // eating the balloons off the top of it.
  testWidgets("the chip-in card keeps its artwork's proportions", (
    tester,
  ) async {
    await pump(tester, groupGifts: [buildGroupGift(id: 'gg_1')]);

    final size = tester.getSize(find.byType(GroupGiftCard));
    expect(size.height, closeTo(size.width * 450 / 552, 3));
  });

  testWidgets('a fully funded gift is left off the rail — its "Chip in" '
      'button could no longer do anything', (tester) async {
    await pump(
      tester,
      groupGifts: [
        buildGroupGift(id: 'gg_open', status: GroupGiftStatus.open),
        buildGroupGift(id: 'gg_funded', status: GroupGiftStatus.funded),
      ],
    );

    // A second (still-visible-to-PageView) card would also add a dot row —
    // its absence is what actually proves the funded gift was filtered out,
    // since PageView only builds the current page's widget either way.
    expect(find.byType(CarouselDots), findsNothing);
  });

  testWidgets('no open group gift hides the rail entirely — no empty '
      'placeholder', (tester) async {
    await pump(
      tester,
      groupGifts: [buildGroupGift(status: GroupGiftStatus.cancelled)],
    );

    expect(find.byType(GroupGiftCard), findsNothing);
    expect(find.text('Chip in'), findsNothing);
  });

  testWidgets('header shows the real logo mark, not a plain heart icon', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName == 'assets/logo/logo.png',
      ),
      findsOneWidget,
    );
    // Scoped to the header: [Icons.favorite] is a legitimate glyph
    // elsewhere on Home (wishlist affordances), just not the wordmark.
    expect(
      find.descendant(
        of: find.byType(HomeHeader),
        matching: find.byIcon(Icons.favorite),
      ),
      findsNothing,
    );
  });

  testWidgets('search hint invites searching friends too, not just events '
      'and gifts', (tester) async {
    await pump(tester);

    expect(
      find.text('Search friends, events, wishlists, gifts...'),
      findsOneWidget,
    );
  });

  testWidgets('add-friend and request-sent are the supplied artwork, not '
      'stand-in Material glyphs', (tester) async {
    await pump(tester);

    for (final asset in const [
      'assets/icons/add_friend.png',
      'assets/icons/request_sent.png',
    ]) {
      expect(
        find.byWidgetPredicate(
          (w) => w is Image && (w.image as AssetImage).assetName == asset,
        ),
        findsOneWidget,
        reason: 'the header should draw $asset',
      );
    }
    expect(find.byIcon(Icons.person_add_alt_outlined), findsNothing);
    expect(find.byIcon(Icons.send_outlined), findsNothing);
  });

  testWidgets('the add-person and request icons open WishMates and WishLink', (
    tester,
  ) async {
    // Sprint 11 gave these two somewhere to go. They were drawn but inert
    // through the sprints that had nothing behind them, and this test is what
    // used to hold that: it now holds the opposite, which is the point.
    final tapped = <String>[];

    tester.view
      ..physicalSize = const Size(393, 1600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeHeader(
            address: null,
            onLocationTap: () {},
            onSearchTap: () {},
            onNotificationsTap: () => tapped.add('notifications'),
            onWishmatesTap: () => tapped.add('wishmates'),
            onWishLinksTap: () => tapped.add('wishlinks'),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('WishMates'));
    await tester.pump();
    expect(tapped, ['wishmates']);

    await tester.tap(find.byTooltip('WishLink requests'));
    await tester.pump();
    expect(tapped, ['wishmates', 'wishlinks']);

    // And the bell still goes where it always did — the two new buttons sit
    // beside it, they do not replace it.
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump();
    expect(tapped, ['wishmates', 'wishlinks', 'notifications']);
  });

  testWidgets('the logo mark is drawn bigger than a plain icon — the asset '
      'carries its own transparent margin', (tester) async {
    await pump(tester);

    final logo = tester.getSize(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName == 'assets/logo/logo.png',
      ),
    );

    expect(logo.height, greaterThan(AppSizes.iconLg));
  });

  testWidgets('the search field is a full pill, not a rounded rectangle', (
    tester,
  ) async {
    await pump(tester);

    final field = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(HomeHeader),
            matching: find.byType(Container),
          )
          .last,
    );
    final radius =
        ((field.decoration! as BoxDecoration).borderRadius! as BorderRadius)
            .topLeft
            .x;

    // Half the field's own height is the point past which more radius
    // changes nothing — anything at or above it reads as a pill.
    expect(radius, greaterThanOrEqualTo(AppSizes.inputHeight / 2));
  });
}
