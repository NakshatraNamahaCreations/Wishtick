import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/auth/domain/auth_user.dart';
import 'package:wishtick_flutter/features/auth/presentation/session_controller.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/event.dart';
import 'package:wishtick_flutter/features/events/presentation/event_detail_screen.dart';

import '../../helpers/events_fakes.dart';

/// The host's own view of an event.
///
/// Tapping a card in "My Events" used to open the guest list, which meant a
/// host could not look at their own party — not the invitation they designed,
/// not the date, not what they wrote about it. This screen is where that tap
/// goes now.
void main() {
  late FakeEventsRepository repo;

  setUp(() => repo = FakeEventsRepository());

  Future<void> pump(WidgetTester tester, {ThemeData? theme}) async {
    tester.view
      ..physicalSize = const Size(393, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          eventsRepositoryProvider.overrideWithValue(repo),
          // The screen names the host from the session — it is only ever
          // reached from that user's own "My Events".
          sessionProvider.overrideWith(_SignedInAsJayanth.new),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: const EventDetailScreen(eventId: 'evt_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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

  testWidgets('the invitation row invites you to make one when there is none', (
    tester,
  ) async {
    repo.event = buildEvent();
    await pump(tester);

    expect(find.text('Design one to send'), findsOneWidget);
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
