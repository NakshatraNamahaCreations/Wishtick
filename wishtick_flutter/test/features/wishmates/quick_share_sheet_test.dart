import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';
import 'package:wishtick_flutter/features/wishmates/presentation/widgets/quick_share_sheet.dart';

import '../../helpers/wishmates_fakes.dart';

/// The quick-share sheet — the grid of WishMates that replaced typing an
/// address.
///
/// The rule the tests keep coming back to is that a private thing has no link:
/// its guests are the people picked here, and offering a URL that admits
/// nobody would be worse than offering none.
void main() {
  late FakeWishmatesRepository repo;

  setUp(
    () => repo = FakeWishmatesRepository(
      mates: [
        buildWishmate(userId: 'u_1', displayName: 'Priyal Sharma'),
        buildWishmate(userId: 'u_2', displayName: 'Rohan Prasad'),
        buildWishmate(userId: 'u_3', displayName: 'Ananya R'),
      ],
    ),
  );

  Future<void> pump(
    WidgetTester tester,
    ShareTarget target, {
    ThemeData? theme,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 1200)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [wishmatesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: Scaffold(body: QuickShareSheet(target: target)),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  const privateList = WishlistShareTarget(
    wishlistId: 'wl_1',
    title: 'Jay Birthday',
    slug: null,
    isPublic: false,
  );
  const publicList = WishlistShareTarget(
    wishlistId: 'wl_1',
    title: 'Jay Birthday',
    slug: 'abc123',
    isPublic: true,
  );
  const publicEvent = EventShareTarget(
    eventId: 'ev_1',
    title: 'Ananya’s Birthday',
    slug: 'party99',
    isPublic: true,
  );

  testWidgets('shows every WishMate as somewhere to send it', (tester) async {
    await pump(tester, privateList);

    expect(find.text('Priyal Sharma'), findsOneWidget);
    expect(find.text('Rohan Prasad'), findsOneWidget);
    expect(find.text('Ananya R'), findsOneWidget);
  });

  testWidgets('a private thing offers no link, and says why', (tester) async {
    await pump(tester, privateList);

    expect(find.textContaining('only the WishMates you pick'), findsOneWidget);
    expect(find.text('Copy link'), findsNothing);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('a public thing offers its link alongside the grid', (
    tester,
  ) async {
    await pump(tester, publicList);

    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.textContaining('only the WishMates you pick'), findsNothing);
  });

  testWidgets('a public list with no slug yet still offers no link — there is '
      'nothing to point at until it has been made shareable', (tester) async {
    await pump(
      tester,
      const WishlistShareTarget(
        wishlistId: 'wl_1',
        title: 'Jay Birthday',
        slug: null,
        isPublic: true,
      ),
    );

    expect(find.text('Copy link'), findsNothing);
  });

  testWidgets('Send is dead until somebody is picked', (tester) async {
    await pump(tester, privateList);

    final before = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(before.onPressed, isNull);

    await tester.tap(find.text('Priyal Sharma'));
    await tester.pump();

    final after = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(after.onPressed, isNotNull);
    // The count is the confirmation that the tap registered on the right one.
    expect(find.text('Send to 1'), findsOneWidget);
  });

  testWidgets('tapping again deselects — a mis-tap must be undoable', (
    tester,
  ) async {
    await pump(tester, privateList);

    await tester.tap(find.text('Priyal Sharma'));
    await tester.pump();
    await tester.tap(find.text('Rohan Prasad'));
    await tester.pump();
    expect(find.text('Send to 2'), findsOneWidget);

    await tester.tap(find.text('Priyal Sharma'));
    await tester.pump();
    expect(find.text('Send to 1'), findsOneWidget);
  });

  testWidgets('an empty WishMates list explains that there is nobody to pick, '
      'rather than showing an empty grid', (tester) async {
    repo.mates = [];
    await pump(tester, privateList);

    expect(find.textContaining('No WishMates yet'), findsOneWidget);
  });

  testWidgets('a failed load says so instead of spinning', (tester) async {
    repo.failWith = fakeApiFailure;
    await pump(tester, privateList);

    expect(find.text('Could not load your WishMates.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  group('link building', () {
    test('a wishlist link is the deep link, not the backend’s web URL', () {
      // ShareInfo.url comes from the server's WEB_APP_URL, which is
      // localhost:5173 in development — useless in a share. The app builds its
      // own from the slug so the URL is always one the app can also open.
      expect(publicList.shareUrl, 'https://wishtick.com/w/abc123');
    });

    test('an event link points at the join path, not a personal invite', () {
      // `/i/<token>` addresses one person; a shared link has to be `/e/<slug>`,
      // which anyone may open and which identifies them by signing in.
      expect(publicEvent.shareUrl, 'https://wishtick.com/e/party99');
    });

    test('a private target has no link at all', () {
      expect(privateList.shareUrl, isNull);
    });
  });

  testWidgets('renders on a dark page', (tester) async {
    await pump(tester, publicList, theme: AppTheme.dark);

    expect(tester.takeException(), isNull);
  });

  group('the sheet is as tall as its contents', () {
    /// The sheet's own painted height, which is what the user sees.
    double heightOf(WidgetTester tester) => tester
        .getRect(
          find
              .descendant(
                of: find.byType(QuickShareSheet),
                matching: find.byType(Container),
              )
              .first,
        )
        .height;

    Future<double> withMates(WidgetTester tester, int count) async {
      repo = FakeWishmatesRepository(
        mates: [
          for (var i = 0; i < count; i++)
            buildWishmate(userId: 'u_$i', displayName: 'Mate $i'),
        ],
      );
      await pump(tester, publicList);
      return heightOf(tester);
    }

    testWidgets('one WishMate does not open half a screen of nothing', (
      tester,
    ) async {
      final height = await withMates(tester, 1);

      // It used to open at a flat 75% of the screen however many people were
      // in it. Anything near that is the bug, whatever the exact layout.
      expect(height, lessThan(1200 * 0.5));
    });

    testWidgets('more WishMates makes it taller', (tester) async {
      // Four per row, so 1 and 5 differ by a whole row.
      final one = await withMates(tester, 1);
      final five = await withMates(tester, 5);

      expect(five, greaterThan(one));
    });

    testWidgets('but never past the cap, so the grid scrolls instead of '
        'covering the page', (tester) async {
      final many = await withMates(tester, 60);

      expect(many, lessThanOrEqualTo(1200 * 0.85 + 1));
      // And it is still usable at that size: the send button has to be on
      // screen, not pushed off the bottom by the grid.
      expect(find.text('Send'), findsOneWidget);
    });

    testWidgets('an empty list stays compact too', (tester) async {
      final height = await withMates(tester, 0);

      expect(height, lessThan(1200 * 0.5));
      expect(find.textContaining('No WishMates yet'), findsOneWidget);
    });
  });
}
