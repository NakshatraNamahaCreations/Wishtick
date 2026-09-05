import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/data/invite_repository.dart';
// Both declare an `RsvpResponse`; the guest-side one is what this file uses.
import 'package:wishtick_flutter/features/events/domain/event.dart'
    show WishtickEventDetail;
import 'package:wishtick_flutter/features/events/domain/event_wishlist_request.dart';
import 'package:wishtick_flutter/features/events/domain/public_invite.dart';
import 'package:wishtick_flutter/features/events/presentation/invite_screen.dart';
import 'package:wishtick_flutter/features/events/presentation/my_events_screen.dart';

import '../../helpers/events_fakes.dart';
import '../../helpers/gifting_fakes.dart';

/// A guest offering their own wishlist to an event, and the host answering.
///
/// The whole exchange used to happen in silence. The host was never told an
/// offer had arrived, the queue sits at the foot of one event's page with
/// nothing pointing at it, and the guest got one snackbar and then had no way
/// to learn what had become of their list.
void main() {
  group("the host's list badges what is waiting", () {
    late FakeEventsRepository repo;

    Future<void> pump(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const MyEventsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an event with offers waiting says how many', (tester) async {
      repo = FakeEventsRepository(
        hosted: [
          buildEvent(id: 'e1', title: 'Party', pendingWishlistCount: 2),
          buildEvent(id: 'e2', title: 'Quiet one'),
        ],
      );
      await pump(tester);

      expect(find.text('2 waiting'), findsOneWidget);
    });

    testWidgets('nothing waiting draws no badge at all', (tester) async {
      repo = FakeEventsRepository(
        hosted: [buildEvent(id: 'e1', title: 'Party')],
      );
      await pump(tester);

      expect(find.textContaining('waiting'), findsNothing);
    });

    testWidgets('the badge gives way to the tick while picking cards', (
      tester,
    ) async {
      // Both sit on the artwork, and a count is not what the host is reading
      // when they are choosing what to delete.
      repo = FakeEventsRepository(
        hosted: [buildEvent(id: 'e1', title: 'Party', pendingWishlistCount: 2)],
      );
      await pump(tester);
      expect(find.text('2 waiting'), findsOneWidget);

      await tester.longPress(find.text('Party'));
      await tester.pumpAndSettle();

      expect(find.text('2 waiting'), findsNothing);
    });

    test('the count comes off the wire, defaulting to none', () {
      expect(
        WishtickEventDetail.fromJson({
          'id': 'e1',
          'title': 'Party',
          'type': 'birthday',
          'startsAt': '2026-09-05T14:00:00.000Z',
          'timezone': 'Asia/Kolkata',
          'visibility': 'private',
          'status': 'published',
          'createdAt': '2026-09-01T00:00:00.000Z',
          'pendingWishlistCount': 3,
        }).pendingWishlistCount,
        3,
      );
      // A guest's view of an event carries no count; it must not throw.
      expect(
        WishtickEventDetail.fromJson({
          'id': 'e1',
          'title': 'Party',
          'type': 'birthday',
          'startsAt': '2026-09-05T14:00:00.000Z',
          'timezone': 'Asia/Kolkata',
          'visibility': 'private',
          'status': 'published',
          'createdAt': '2026-09-01T00:00:00.000Z',
        }).pendingWishlistCount,
        0,
      );
    });
  });

  group('the guest can see what became of their offer', () {
    late FakeInviteRepository invites;
    late FakeEventsRepository events;

    setUp(() {
      invites = FakeInviteRepository(
        invite: buildInvite(rsvp: RsvpResponse.yes),
      );
      events = FakeEventsRepository();
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 1600)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inviteRepositoryProvider.overrideWithValue(invites),
            eventsRepositoryProvider.overrideWithValue(events),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const InviteScreen(token: 'tok_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('with no offer yet, the row invites them to make one', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Add your wishlist'), findsOneWidget);
      expect(find.text('Waiting for the host to accept it'), findsNothing);
    });

    testWidgets('a pending offer says it is waiting on the host', (
      tester,
    ) async {
      // One snackbar at the moment of offering was the whole of the feedback
      // before this.
      events.wishlistOffers = [
        buildWishlistOffer(eventId: 'ev_1', wishlistTitle: 'For Rohan'),
      ];
      await pump(tester);

      expect(find.text('For Rohan'), findsOneWidget);
      expect(find.text('Waiting for the host to accept it'), findsOneWidget);
      expect(find.text('Add your wishlist'), findsNothing);
      // Nothing to do but wait, so nothing is offered.
      expect(find.text('Offer another'), findsNothing);
    });

    testWidgets('an approved offer says it is showing', (tester) async {
      events.wishlistOffers = [
        buildWishlistOffer(
          eventId: 'ev_1',
          status: EventWishlistRequestStatus.approved,
        ),
      ];
      await pump(tester);

      expect(find.text('Showing on this event'), findsOneWidget);
    });

    testWidgets('a declined offer says so, and frees them to offer another', (
      tester,
    ) async {
      events.wishlistOffers = [
        buildWishlistOffer(
          eventId: 'ev_1',
          status: EventWishlistRequestStatus.rejected,
        ),
      ];
      await pump(tester);

      expect(find.text('The host did not add this one'), findsOneWidget);
      expect(find.text('Offer another'), findsOneWidget);
    });

    testWidgets('an offer to a different event is not shown on this one', (
      tester,
    ) async {
      events.wishlistOffers = [buildWishlistOffer(eventId: 'some_other_event')];
      await pump(tester);

      expect(find.text('Add your wishlist'), findsOneWidget);
      expect(find.text('Waiting for the host to accept it'), findsNothing);
    });
  });

  group('who may offer a wishlist at all', () {
    late FakeInviteRepository invites;
    late FakeEventsRepository events;

    setUp(() => events = FakeEventsRepository());

    Future<void> pumpWithRsvp(WidgetTester tester, RsvpResponse rsvp) async {
      tester.view
        ..physicalSize = const Size(393, 1600)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      invites = FakeInviteRepository(invite: buildInvite(rsvp: rsvp));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inviteRepositoryProvider.overrideWithValue(invites),
            eventsRepositoryProvider.overrideWithValue(events),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const InviteScreen(token: 'tok_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Going and Maybe are offered the row', (tester) async {
      for (final rsvp in [RsvpResponse.yes, RsvpResponse.maybe]) {
        await pumpWithRsvp(tester, rsvp);
        expect(find.text('Add your wishlist'), findsOneWidget, reason: '$rsvp');
      }
    });

    testWidgets('someone who declined is not, because the server refuses', (
      tester,
    ) async {
      // The row used to appear for anyone who had answered at all, so a guest
      // who said Can't go tapped it and got a "not found" error.
      await pumpWithRsvp(tester, RsvpResponse.no);

      expect(find.text('Add your wishlist'), findsNothing);
    });

    testWidgets('nor is someone who has not answered', (tester) async {
      await pumpWithRsvp(tester, RsvpResponse.pending);

      expect(find.text('Add your wishlist'), findsNothing);
    });

    test('attending is Going and Maybe, and nothing else', () {
      expect(RsvpResponse.yes.isAttending, isTrue);
      expect(RsvpResponse.maybe.isAttending, isTrue);
      expect(RsvpResponse.no.isAttending, isFalse);
      expect(RsvpResponse.pending.isAttending, isFalse);
    });
  });
}
