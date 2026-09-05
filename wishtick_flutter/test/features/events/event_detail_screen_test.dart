import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_image.dart';
import 'package:wishtick_flutter/features/auth/domain/auth_user.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/event.dart';
import 'package:wishtick_flutter/features/events/presentation/event_detail_screen.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';

import '../../helpers/events_fakes.dart';
import '../../helpers/wishmates_fakes.dart';

/// The host's own view of an event.
///
/// Tapping a card in "My Events" used to open the guest list, which meant a
/// host could not look at their own party — not the invitation they designed,
/// not the date, not what they wrote about it. This screen is where that tap
/// goes now.
void main() {
  late FakeEventsRepository repo;

  setUp(() => repo = FakeEventsRepository());

  late FakeWishmatesRepository mates;

  setUp(() => mates = FakeWishmatesRepository(mates: [buildWishmate()]));

  // Riverpod 3 does not export the `Override` type, so this cannot be a typed
  // helper; the inferred return type is what `ProviderScope` takes.
  overrides() => [
    eventsRepositoryProvider.overrideWithValue(repo),
    wishmatesRepositoryProvider.overrideWithValue(mates),
    // The screen names the host from the session — it is only ever
    // reached from that user's own "My Events".
    sessionProvider.overrideWith(_SignedInAsJayanth.new),
  ];

  Future<void> pump(WidgetTester tester, {ThemeData? theme}) async {
    tester.view
      ..physicalSize = const Size(393, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: overrides(),
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: const EventDetailScreen(eventId: 'evt_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Under a router with Share beneath the event, as in the app's own route
  /// table — for the row that navigates.
  Future<void> pumpRouted(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.eventDetail('evt_1'),
            routes: [
              GoRoute(
                path: '/events/:id',
                builder: (_, s) =>
                    EventDetailScreen(eventId: s.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'share',
                    builder: (_, s) =>
                        Scaffold(body: Text('share ${s.pathParameters['id']}')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The tappable behind a suggestion row, or null when the row is dead.
  VoidCallback? rowTap(WidgetTester tester, String title) => tester
      .widget<InkWell>(
        find.ancestor(of: find.text(title), matching: find.byType(InkWell)),
      )
      .onTap;

  testWidgets('shows the event the host made, not their guest list', (
    tester,
  ) async {
    repo.event = buildEvent(
      title: "Siya's 24th",
      description: 'Join us as we celebrate.',
    );
    await pump(tester);

    expect(find.text("Siya's 24th"), findsOneWidget);
    expect(find.text('About Event'), findsOneWidget);
    expect(find.text('Join us as we celebrate.'), findsOneWidget);
    // The guest list is one row among several here rather than the whole
    // destination.
    expect(find.text('Guest List'), findsOneWidget);
  });

  testWidgets('the venue is shown, unlike on the invitee view', (tester) async {
    repo.event = buildEvent(venue: 'Zero degree on Hill, Bangalore');
    await pump(tester);

    // An Event carries a venue; the token-based invite view has none, which is
    // why it omits the line rather than inventing one.
    expect(find.text('Zero degree on Hill, Bangalore'), findsOneWidget);
  });

  testWidgets('an event with no venue simply omits the line', (tester) async {
    repo.event = buildEvent(venue: null);
    await pump(tester);

    expect(find.byIcon(Icons.place_outlined), findsNothing);
    // The time is always there, so the section never collapses to nothing.
    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });

  testWidgets('a draft says so — only the host can see one at all', (
    tester,
  ) async {
    repo.event = buildEvent(status: EventStatus.draft);
    await pump(tester);

    expect(find.text('Draft — not sent yet'), findsOneWidget);
  });

  testWidgets('a published event is labelled published', (tester) async {
    repo.event = buildEvent(status: EventStatus.published);
    await pump(tester);

    expect(find.text('Published'), findsOneWidget);
  });

  testWidgets('the wishlist row is there whether or not a list is attached', (
    tester,
  ) async {
    repo.event = buildEvent();
    await pump(tester);

    // Hiding the row left no way to attach a list, and no hint that an event
    // can carry one at all.
    expect(find.text('View Wishlist'), findsOneWidget);
    expect(
      find.text('Attach one so guests know what to bring'),
      findsOneWidget,
    );

    repo.event = buildEvent(wishlistIds: const ['wl_1']);
    await pump(tester);
    expect(find.text('1 list attached'), findsOneWidget);
  });

  testWidgets('the host is named', (tester) async {
    repo.event = buildEvent();
    await pump(tester);

    // An EventView carries no host name — this screen is only ever reached
    // from the signed-in user's own "My Events", so the host is them.
    expect(find.text('Hosted By'), findsOneWidget);
    expect(find.text('Jayanth'), findsOneWidget);
  });

  testWidgets('the invitation is shown whole, at its own proportions', (
    tester,
  ) async {
    // A fixed 3:4 box cropped the last line off every card of another shape.
    repo.event = buildEvent(inviteMediaUrl: 'https://cdn.test/invite.png');
    await pump(tester);

    final image = tester.widget<WishtickImage>(find.byType(WishtickImage));
    expect(image.url, 'https://cdn.test/invite.png');
    expect(image.fit, BoxFit.fitWidth);
    expect(
      find.ancestor(
        of: find.byType(WishtickImage),
        matching: find.byType(AspectRatio),
      ),
      findsNothing,
    );
  });

  testWidgets('a PDF invitation is not drawn as a broken image', (
    tester,
  ) async {
    repo.event = buildEvent(inviteMediaUrl: 'https://cdn.test/invite.pdf');
    await pump(tester);

    expect(find.byType(WishtickImage), findsNothing);
  });

  testWidgets('Quick Suggestions is only what the design has on it', (
    tester,
  ) async {
    repo.event = buildEvent(status: EventStatus.published);
    await pump(tester);

    // Wishlist first, then guests — the design's order.
    expect(find.text('View Wishlist'), findsOneWidget);
    expect(find.text('Guest List'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('View Wishlist')).dy,
      lessThan(tester.getTopLeft(find.text('Guest List')).dy),
    );

    // Inviting moved to the bar; nothing about the invitation's design was
    // ever a row here.
    expect(find.text('Invite WishMates'), findsNothing);
    expect(find.text('Share Invitation Link'), findsNothing);
    expect(find.text('Invitation'), findsNothing);
    expect(find.text('Change the design'), findsNothing);
  });

  testWidgets('the bar carries an invite action, which opens every way in', (
    tester,
  ) async {
    repo.event = buildEvent(status: EventStatus.published);
    await pump(tester);

    await tester.tap(find.byIcon(Icons.person_add_alt_1_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Invite people'), findsOneWidget);
    expect(find.text('Invite WishMates'), findsOneWidget);
    // For the friends who are not on Wishtick yet, which is most of them on
    // the day a host starts.
    expect(find.text('Invite from Contacts'), findsOneWidget);
    expect(find.text('Share Invitation Link'), findsOneWidget);
  });

  testWidgets('Invite WishMates opens the WishMates picker', (tester) async {
    repo.event = buildEvent(status: EventStatus.published);
    await pump(tester);

    await tester.tap(find.byIcon(Icons.person_add_alt_1_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite WishMates'));
    await tester.pumpAndSettle();

    // The picker replaced the sheet rather than stacking on it.
    expect(find.text('Invite people'), findsNothing);
    expect(find.text('Share with WishMates'), findsOneWidget);
    expect(find.text('Priyal Sharma'), findsOneWidget);
  });

  testWidgets('Share Invitation Link opens the share screen', (tester) async {
    repo.event = buildEvent(status: EventStatus.published);
    await pumpRouted(tester);

    await tester.tap(find.byIcon(Icons.person_add_alt_1_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share Invitation Link'));
    await tester.pumpAndSettle();

    expect(find.text('share evt_1'), findsOneWidget);
  });

  testWidgets('a draft cannot be shared yet, and the sheet says so', (
    tester,
  ) async {
    // The server refuses invites for a draft. A dead row carrying the reason
    // beats a tap that fails — and beats an action that simply vanishes,
    // which would teach the host nothing about when it comes back.
    repo.event = buildEvent(status: EventStatus.draft);
    await pump(tester);

    await tester.tap(find.byIcon(Icons.person_add_alt_1_outlined));
    await tester.pumpAndSettle();

    expect(rowTap(tester, 'Invite WishMates'), isNull);
    expect(rowTap(tester, 'Invite from Contacts'), isNull);
    expect(rowTap(tester, 'Share Invitation Link'), isNull);
    expect(find.text('Only a published event can be shared'), findsNWidgets(3));
  });

  testWidgets('a failed load offers a retry rather than spinning forever', (
    tester,
  ) async {
    repo.failure = Exception('offline');
    await pump(tester);

    // Riverpod retries a failed provider, so it is failed *and* loading —
    // matching the loading case first would leave a spinner on screen for a
    // request that has already given up.
    expect(find.text('Could not load this event.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('renders on a dark page', (tester) async {
    repo.event = buildEvent(description: 'Join us.');
    await pump(tester, theme: AppTheme.dark);

    expect(tester.takeException(), isNull);
    expect(find.text('About Event'), findsOneWidget);
  });

  test('the detail route is the event id on its own', () {
    // The grid opens this, and the more specific `/events/:id/guests` and
    // `/events/:id/invite` have to stay reachable beside it.
    expect(AppRoutes.eventDetail('evt_1'), '/events/evt_1');
    expect(AppRoutes.eventGuests('evt_1'), '/events/evt_1/guests');
    expect(AppRoutes.eventInviteTemplates('evt_1'), '/events/evt_1/invite');
  });
}

/// A signed-in host, so "Hosted By" has a name to print.
class _SignedInAsJayanth extends SessionController {
  @override
  SessionState build() => SessionState(
    status: SessionStatus.authenticated,
    user: AuthUser(
      id: 'u_1',
      name: 'Jayanth',
      emailVerified: true,
      phoneVerified: true,
      roles: const ['user'],
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );
}
