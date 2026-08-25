import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';
import 'package:wishtick_flutter/features/wishmates/domain/wishmate.dart';
import 'package:wishtick_flutter/features/wishmates/presentation/people_search_screen.dart';
import 'package:wishtick_flutter/features/wishmates/presentation/person_profile_screen.dart';
import 'package:wishtick_flutter/features/wishmates/presentation/wishlinks_screen.dart';
import 'package:wishtick_flutter/features/wishmates/presentation/wishmates_list_screen.dart';

import '../../helpers/wishmates_fakes.dart';

/// The five WishMates screens (`4177:138`, `4177:77`, `4177:111`, `4177:42`,
/// `4177:217` / `4177:267`).
void main() {
  late FakeWishmatesRepository repo;

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    ThemeData? theme,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 1600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // A fresh key per call so re-pumping inside one test builds a new
        // container: without it the second pump reuses the first's cached
        // providers and the repository is never asked again.
        key: UniqueKey(),
        overrides: [wishmatesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: theme ?? AppTheme.light, home: screen),
      ),
    );
    // Enough frames for the futures to settle and the rebuilds to land.
    // Not `pumpAndSettle`: the loading state holds a CircularProgressIndicator,
    // which never stops animating and would hang the pump.
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  setUp(() => repo = FakeWishmatesRepository());

  // ── `4177:138` ────────────────────────────────────────────────────────────

  group('WishMates list (4177:138)', () {
    testWidgets('counts the WishMates in the section heading', (tester) async {
      repo.mates = [
        buildWishmate(userId: 'u_1', username: 'priyalsharma'),
        buildWishmate(userId: 'u_2', username: 'ananyar24'),
      ];
      await pump(tester, const WishmatesListScreen());

      expect(find.text('My WishMates (2)'), findsOneWidget);
      expect(find.text('@priyalsharma'), findsOneWidget);
      expect(find.text('@ananyar24'), findsOneWidget);
    });

    testWidgets('the banner announces the pending count, and pluralises it', (
      tester,
    ) async {
      repo.pending = 2;
      await pump(tester, const WishmatesListScreen());
      expect(find.text('2 New Requests'), findsOneWidget);

      repo.pending = 1;
      await pump(tester, const WishmatesListScreen());
      expect(find.text('1 New Request'), findsOneWidget);
    });

    testWidgets('the banner stays put at zero — it is the only way to the '
        'WishLink tabs, and a row that vanishes takes its navigation with it', (
      tester,
    ) async {
      repo.pending = 0;
      await pump(tester, const WishmatesListScreen());

      expect(find.text('No new requests'), findsOneWidget);
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('offers a way to find people — the empty state tells you to '
        'search, so the screen has to let you', (tester) async {
      await pump(tester, const WishmatesListScreen());

      expect(find.byTooltip('Find people'), findsOneWidget);
    });

    testWidgets('an empty list explains itself rather than showing nothing', (
      tester,
    ) async {
      await pump(tester, const WishmatesListScreen());

      expect(find.text('My WishMates (0)'), findsOneWidget);
      expect(find.textContaining('No WishMates yet'), findsOneWidget);
    });

    testWidgets('a failed load says so instead of spinning — Riverpod retries '
        'a broken provider, so it is loading and failed at the same time', (
      tester,
    ) async {
      repo.failWith = fakeApiFailure;
      await pump(tester, const WishmatesListScreen());

      expect(find.text('Could not load your WishMates.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('removing a WishMate asks first, and only then calls through', (
      tester,
    ) async {
      repo.mates = [buildWishmate(userId: 'u_1')];
      await pump(tester, const WishmatesListScreen());

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove WishMate').last);
      await tester.pumpAndSettle();

      // The dialog is up and nothing has happened yet — an accidental menu tap
      // must not sever a connection.
      expect(find.text('Remove WishMate?'), findsOneWidget);
      expect(repo.calls, isEmpty);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove WishMate').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();

      expect(repo.calls, contains('remove:u_1'));
    });
  });

  // ── `4177:77` / `4177:111` ────────────────────────────────────────────────

  group('WishLink (4177:77 / 4177:111)', () {
    testWidgets('both tabs carry their own count', (tester) async {
      repo.received = [
        buildWishLink(linkId: 'l_1'),
        buildWishLink(linkId: 'l_2'),
      ];
      repo.sent = [buildWishLink(linkId: 'l_3')];
      await pump(tester, const WishLinksScreen());

      expect(find.text('Received (2)'), findsOneWidget);
      expect(find.text('Sent (1)'), findsOneWidget);
    });

    testWidgets('Received offers Accept and Decline; Sent offers Delete', (
      tester,
    ) async {
      repo.received = [buildWishLink(linkId: 'l_1')];
      repo.sent = [buildWishLink(linkId: 'l_9')];
      await pump(tester, const WishLinksScreen());

      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      // Decline is a first-class button, not buried in an overflow menu.
      expect(find.text('Delete'), findsNothing);

      await tester.tap(find.text('Sent (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
    });

    testWidgets('Accept and Decline call through with the link id', (
      tester,
    ) async {
      repo.received = [buildWishLink(linkId: 'l_accept')];
      await pump(tester, const WishLinksScreen());

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('accept:l_accept'));

      repo.calls.clear();
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('decline:l_accept'));
    });

    testWidgets('the Sent tab deletes by withdrawing, not by declining — the '
        'addressee never saw it, so there is nothing to remember', (
      tester,
    ) async {
      repo.sent = [buildWishLink(linkId: 'l_sent')];
      await pump(tester, const WishLinksScreen(initialTab: 1));

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('withdraw:l_sent'));
      expect(repo.calls.any((c) => c.startsWith('decline')), isFalse);
    });

    testWidgets('a request shows the mutual line the frame draws', (
      tester,
    ) async {
      repo.received = [
        buildWishLink(
          person: buildWishmate(
            displayName: 'Krunal',
            username: 'Krunalp',
            mutualCount: 1,
          ),
        ),
      ];
      await pump(tester, const WishLinksScreen());

      expect(find.textContaining('1 mutual friend'), findsOneWidget);
    });

    testWidgets('no mutuals means no mutual line, not "0 mutual friends"', (
      tester,
    ) async {
      repo.received = [
        buildWishLink(
          person: buildWishmate(displayName: 'Siya Sharma', mutualCount: 0),
        ),
      ];
      await pump(tester, const WishLinksScreen());

      expect(find.textContaining('mutual'), findsNothing);
    });
  });

  // ── `4177:42` ─────────────────────────────────────────────────────────────

  group('People search (4177:42)', () {
    testWidgets('nothing is searched until two characters are typed', (
      tester,
    ) async {
      await pump(tester, const PeopleSearchScreen());

      await tester.enterText(find.byType(TextField), 'r');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(
        find.textContaining('searches start at two characters'),
        findsOneWidget,
      );
      expect(repo.calls.any((c) => c.startsWith('search')), isFalse);
    });

    testWidgets('the search pill keeps the height the frames draw, and does '
        'not inherit the theme’s squared-off input fill', (tester) async {
      await pump(tester, const PeopleSearchScreen());

      // `4177:42` measures it at 48. Left to the global InputDecorationTheme
      // it rendered 95 tall with square corners and spilled out through the
      // header's curved foot — which only showed up on the device.
      final field = tester.getSize(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(field.height, 48);

      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.filled, isFalse);
    });

    testWidgets('splits handle-prefix matches into Top Results', (
      tester,
    ) async {
      repo.results = [
        buildWishmate(
          userId: 'u_1',
          username: 'rohanm',
          displayName: 'Rohan Mehta',
          mutualCount: 4,
        ),
        buildWishmate(
          userId: 'u_2',
          username: 'priyalsharma',
          displayName: 'Rohit’s friend',
        ),
      ];
      await pump(tester, const PeopleSearchScreen());

      await tester.enterText(find.byType(TextField), 'ro');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('Top Results'), findsOneWidget);
      expect(find.text('More People'), findsOneWidget);
      expect(find.text('@rohanm'), findsOneWidget);
      expect(find.textContaining('4 mutual friends'), findsOneWidget);
    });

    testWidgets('a leading @ is ignored when splitting, as the server ignores '
        'it when matching', (tester) async {
      repo.results = [
        buildWishmate(username: 'rohanm', displayName: 'Rohan Mehta'),
      ];
      await pump(tester, const PeopleSearchScreen());

      await tester.enterText(find.byType(TextField), '@ro');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('Top Results'), findsOneWidget);
      expect(find.text('More People'), findsNothing);
    });

    testWidgets('an empty result says why someone might not be findable', (
      tester,
    ) async {
      repo.results = const [];
      await pump(tester, const PeopleSearchScreen());

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.textContaining('claimed a'), findsOneWidget);
    });

    testWidgets('clearing the field empties the results immediately, without '
        'waiting out the debounce', (tester) async {
      repo.results = [buildWishmate(username: 'rohanm')];
      await pump(tester, const PeopleSearchScreen());

      await tester.enterText(find.byType(TextField), 'ro');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Top Results'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.text('Top Results'), findsNothing);
    });
  });

  // ── `4177:217` / `4177:267` ───────────────────────────────────────────────

  group('Profile (4177:217 / 4177:267)', () {
    testWidgets('an unconnected profile offers Add WishMate', (tester) async {
      repo
        ..personProfile = buildProfile(
          relationship: WishmateRelationship.none,
          person: buildWishmate(
            displayName: 'Rohan Mehta',
            username: 'rohanm',
            mutualCount: 4,
          ),
        )
        ..suggested = [buildWishmate(userId: 'u_s', username: 'roshinik')];
      await pump(tester, const PersonProfileScreen(userId: 'u_1'));

      expect(find.text('Add WishMate'), findsOneWidget);
      expect(find.text('Remove WishMate'), findsNothing);
      expect(find.text('4 Mutual Friends'), findsOneWidget);
      expect(find.text('Find WishMates'), findsOneWidget);
    });

    testWidgets('a connected profile offers Remove WishMate instead', (
      tester,
    ) async {
      repo
        ..personProfile = buildProfile(
          relationship: WishmateRelationship.wishmates,
          person: buildWishmate(displayName: 'Priyal Sharma'),
        )
        ..suggested = [buildWishmate(userId: 'u_s', username: 'roshinik')];
      await pump(tester, const PersonProfileScreen(userId: 'u_1'));

      expect(find.text('Remove WishMate'), findsOneWidget);
      expect(find.text('Add WishMate'), findsNothing);
      expect(find.text('People You May Know'), findsOneWidget);
    });

    testWidgets('Message is inert until you are connected — the link is the '
        'permission to message', (tester) async {
      repo.personProfile = buildProfile(
        relationship: WishmateRelationship.none,
      );
      await pump(tester, const PersonProfileScreen(userId: 'u_1'));

      final disabled = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Message'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(disabled.onPressed, isNull);
    });

    testWidgets('Add WishMate sends the request', (tester) async {
      repo.personProfile = buildProfile(
        relationship: WishmateRelationship.none,
        person: buildWishmate(userId: 'u_target'),
      );
      await pump(tester, const PersonProfileScreen(userId: 'u_target'));

      await tester.tap(find.text('Add WishMate'));
      await tester.pumpAndSettle();

      // Keyed off the person on screen, not the route parameter: they agree in
      // life, and the displayed person is the one the button is about.
      expect(repo.calls, contains('request:u_target'));
    });

    testWidgets('Recent Activity is drawn only when there is something shared '
        '— an empty section would imply the calendar is visible', (
      tester,
    ) async {
      repo.personProfile = buildProfile(recentActivity: const []);
      await pump(tester, const PersonProfileScreen(userId: 'u_1'));
      expect(find.text('Recent Activity'), findsNothing);

      repo.personProfile = buildProfile(
        relationship: WishmateRelationship.wishmates,
        recentActivity: [
          buildActivity(
            title: 'Ananya’s Birthday',
            venue: 'Infinite Rooftop',
            startsAt: DateTime.now().add(const Duration(days: 3)),
          ),
        ],
      );
      await pump(tester, const PersonProfileScreen(userId: 'u_1'));

      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Ananya’s Birthday'), findsOneWidget);
      expect(find.text('Attending in 3 days'), findsOneWidget);
      expect(find.textContaining('Infinite Rooftop'), findsOneWidget);
    });

    testWidgets('the location row is dropped when the person gave no place', (
      tester,
    ) async {
      repo.personProfile = buildProfile(city: null, country: null);
      await pump(tester, const PersonProfileScreen(userId: 'u_1'));

      expect(find.byIcon(Icons.place_outlined), findsNothing);
      // The join date is public, so its row always stands.
      expect(find.textContaining('Joined Wishtick on'), findsOneWidget);
    });

    testWidgets('your own profile offers no relationship button', (
      tester,
    ) async {
      repo.personProfile = buildProfile(
        relationship: WishmateRelationship.self,
      );
      await pump(tester, const PersonProfileScreen(userId: 'me'));

      expect(find.text('This is you'), findsOneWidget);
      expect(find.text('Add WishMate'), findsNothing);
      expect(find.text('Remove WishMate'), findsNothing);
    });
  });

  // ── Dark ──────────────────────────────────────────────────────────────────

  testWidgets('every Sprint 11 WishMates screen renders on a dark page', (
    tester,
  ) async {
    repo
      ..mates = [buildWishmate()]
      ..received = [buildWishLink()]
      ..results = [buildWishmate()];

    for (final screen in <Widget>[
      const WishmatesListScreen(),
      const WishLinksScreen(),
      const PeopleSearchScreen(),
      const PersonProfileScreen(userId: 'u_1'),
    ]) {
      await pump(tester, screen, theme: AppTheme.dark);
      expect(tester.takeException(), isNull);
    }
  });
}
