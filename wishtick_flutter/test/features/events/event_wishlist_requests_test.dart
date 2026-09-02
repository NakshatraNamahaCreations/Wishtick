import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/event_wishlist_request.dart';
import 'package:wishtick_flutter/features/events/presentation/widgets/event_wishlist_requests.dart';

import '../../helpers/events_fakes.dart';

/// A guest offering their own wishlist to an event, and the host's answer.
///
/// The host's approval is the whole point: an offered list must not appear on
/// the invitation until they take it, and taking it is what opens a private
/// list to the event's guests.
void main() {
  Future<void> pump(
    WidgetTester tester,
    FakeEventsRepository repo, {
    ThemeData? theme,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [eventsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: EventWishlistRequestsSection(eventId: 'ev_1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names the list, who offered it, and how much is on it', (
    tester,
  ) async {
    await pump(
      tester,
      FakeEventsRepository()
        ..wishlistOffers = [
          buildWishlistOffer(
            wishlistTitle: 'My birthday list',
            requestedByName: 'Siya',
            itemCount: 4,
          ),
        ],
    );

    expect(find.text('Guest Wishlists'), findsOneWidget);
    expect(find.text('My birthday list'), findsOneWidget);
    // The two things the host is actually deciding between.
    expect(find.text('Siya offered this list · 4 gifts'), findsOneWidget);
  });

  testWidgets('an empty list is offered without a misleading zero', (
    tester,
  ) async {
    await pump(
      tester,
      FakeEventsRepository()
        ..wishlistOffers = [buildWishlistOffer(itemCount: 0)],
    );

    expect(find.text('Siya offered this list'), findsOneWidget);
    expect(find.textContaining('0 gifts'), findsNothing);
  });

  testWidgets('draws nothing when nobody has offered one', (tester) async {
    await pump(tester, FakeEventsRepository()..wishlistOffers = []);

    expect(find.text('Guest Wishlists'), findsNothing);
    expect(tester.getSize(find.byType(EventWishlistRequestsSection)).height, 0);
  });

  testWidgets('approving sends the answer', (tester) async {
    final repo = FakeEventsRepository()
      ..wishlistOffers = [buildWishlistOffer()];
    await pump(tester, repo);

    await tester.tap(find.text('Show on event'));
    await tester.pumpAndSettle();

    expect(repo.answeredWishlists, [('req_1', true)]);
  });

  testWidgets('declining sends the other answer', (tester) async {
    final repo = FakeEventsRepository()
      ..wishlistOffers = [buildWishlistOffer()];
    await pump(tester, repo);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(repo.answeredWishlists, [('req_1', false)]);
  });

  // An approved list is already on the invitation, so the only thing left to
  // do with it is take it down — and that is not an answer, it is an undo.
  testWidgets('an approved list offers Remove, not Approve', (tester) async {
    await pump(
      tester,
      FakeEventsRepository()
        ..wishlistOffers = [
          buildWishlistOffer(status: EventWishlistRequestStatus.approved),
        ],
    );

    expect(find.text('Showing on this event'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Show on event'), findsNothing);
    expect(find.text('Decline'), findsNothing);
  });

  testWidgets('removing asks first', (tester) async {
    final repo = FakeEventsRepository()
      ..wishlistOffers = [
        buildWishlistOffer(status: EventWishlistRequestStatus.approved),
      ];
    await pump(tester, repo);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Remove this wishlist?'), findsOneWidget);
    expect(repo.removedWishlists, isEmpty);
  });

  testWidgets('backing out of the dialog removes nothing', (tester) async {
    final repo = FakeEventsRepository()
      ..wishlistOffers = [
        buildWishlistOffer(status: EventWishlistRequestStatus.approved),
      ];
    await pump(tester, repo);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(repo.removedWishlists, isEmpty);
  });

  // Dismissing by tapping outside is a no, not a silent yes: "Keep it" pops
  // false explicitly, so only this exercises the null fallback.
  testWidgets('dismissing the dialog removes nothing', (tester) async {
    final repo = FakeEventsRepository()
      ..wishlistOffers = [
        buildWishlistOffer(status: EventWishlistRequestStatus.approved),
      ];
    await pump(tester, repo);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.removedWishlists, isEmpty);
  });

  testWidgets('confirming the dialog sends the removal', (tester) async {
    final repo = FakeEventsRepository()
      ..wishlistOffers = [
        buildWishlistOffer(status: EventWishlistRequestStatus.approved),
      ];
    await pump(tester, repo);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Remove'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.removedWishlists, ['req_1']);
  });

  // The owner may have withdrawn it, or answered on another device, between
  // the queue being drawn and the button being pressed.
  testWidgets('a refusal is shown, not swallowed', (tester) async {
    final repo = FakeEventsRepository()
      ..wishlistOffers = [buildWishlistOffer()];
    await pump(tester, repo);
    repo.failure = const ApiException(
      code: 'VALIDATION_FAILED',
      message: 'This wishlist has already been answered',
      statusCode: 409,
    );

    await tester.tap(find.text('Show on event'));
    await tester.pumpAndSettle();

    expect(
      find.text('This wishlist has already been answered'),
      findsOneWidget,
    );
  });

  testWidgets('renders on a dark page', (tester) async {
    await pump(
      tester,
      FakeEventsRepository()..wishlistOffers = [buildWishlistOffer()],
      theme: AppTheme.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Show on event'), findsOneWidget);
  });
}
