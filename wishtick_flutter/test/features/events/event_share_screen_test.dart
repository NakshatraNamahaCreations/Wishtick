import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wishtick_flutter/core/router/app_routes.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/circle_back_button.dart';
import 'package:wishtick_flutter/features/events/data/events_repository.dart';
import 'package:wishtick_flutter/features/events/domain/event.dart';
import 'package:wishtick_flutter/features/events/presentation/event_share_screen.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';

import '../../helpers/events_fakes.dart';
import '../../helpers/wishlist_fakes.dart';

/// "Share Your Invite" — the screen the wizard lands on, and the first one
/// on which the event exists.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEventsRepository repo;
  late FakeWishlistRepository wishlists;

  /// What the last `Clipboard.setData` carried.
  String? copied;

  setUp(() {
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });

    repo = FakeEventsRepository(
      event: buildEvent(
        status: EventStatus.published,
        visibility: EventVisibility.inviteOnly,
        inviteMediaUrl: 'https://cdn.test/invite.png',
        wishlistIds: const ['wl_1'],
      ),
    );
    wishlists = FakeWishlistRepository(
      wishlists: [buildWishlist(id: 'wl_1', itemCount: 8)],
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Under a router, with the event page beneath Share as in the app's own
  /// route table, so back has somewhere real to go.
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: AppRoutes.eventShare('evt_1'),
      routes: [
        GoRoute(
          path: '/events/:id',
          builder: (_, s) =>
              Scaffold(body: Text('event ${s.pathParameters['id']}')),
          routes: [
            GoRoute(
              path: 'share',
              builder: (_, s) =>
                  EventShareScreen(eventId: s.pathParameters['id']!),
            ),
          ],
        ),
        // Before `/wishlist/:id`, or "create" is read as an id.
        GoRoute(
          path: AppRoutes.wishlistCreate,
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(buildWishlist(id: 'wl_new')),
              child: const Text('Save list'),
            ),
          ),
        ),
        GoRoute(
          path: '/wishlist/:id',
          builder: (_, s) =>
              Scaffold(body: Text('wishlist ${s.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventsRepositoryProvider.overrideWithValue(repo),
          wishlistRepositoryProvider.overrideWithValue(wishlists),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the invitation beside what it is for', (tester) async {
    await pump(tester);

    expect(find.text('Share Your Invite'), findsOneWidget);
    expect(find.text('Invite WishMates & Family'), findsOneWidget);
    expect(find.text("Siya's 24th"), findsOneWidget);
    expect(find.text('Mysore Socials'), findsOneWidget);
    // In the device's zone, as the event page shows the same date.
    final expected = DateFormat(
      'd MMM yyyy · h:mm a',
    ).format(DateTime.utc(2026, 7, 19, 14, 30).toLocal());
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('counts the items on the linked wishlist, and opens it', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('8 items ready to gift'), findsOneWidget);

    await tester.tap(find.text('Linked Wishlist'));
    await tester.pumpAndSettle();

    expect(find.text('wishlist wl_1'), findsOneWidget);
  });

  testWidgets('with no list yet, the row makes one and links it', (
    tester,
  ) async {
    repo.event = buildEvent(
      status: EventStatus.published,
      visibility: EventVisibility.inviteOnly,
    );
    await pump(tester);

    expect(
      find.text('No wishlist linked yet — tap to create one'),
      findsOneWidget,
    );

    await tester.tap(find.text('Linked Wishlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save list'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls.single['wishlistIds'], ['wl_new']);
  });

  testWidgets("Copy link puts the event's own link on the clipboard", (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(copied, 'https://wt.test/e/siya-24th');
    expect(find.text('Link copied to clipboard'), findsOneWidget);
  });

  testWidgets('the grid is dead without a share link', (tester) async {
    // Only the host gets a link. A guest who lands here sees what the screen
    // is for, and can do nothing with it.
    repo.event = buildEvent(
      status: EventStatus.published,
      visibility: EventVisibility.inviteOnly,
      shareable: false,
    );
    await pump(tester);

    final tile = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Copy link'), matching: find.byType(InkWell))
          .first,
    );
    expect(tile.onTap, isNull);
  });

  testWidgets("a private event's link is refused, so none is handed out", (
    tester,
  ) async {
    // The server 404s a private event's link for everybody. Handing it out
    // would send guests to a dead page with no explanation on either side.
    repo.event = buildEvent(
      status: EventStatus.published,
      visibility: EventVisibility.private,
    );
    await pump(tester);

    expect(find.text('A link won’t open this event'), findsOneWidget);
    expect(find.text('Copy link'), findsNothing);
    expect(find.text('Share Your Invite Via'), findsNothing);
  });

  testWidgets('back lands on the event page, not on the wizard', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byType(CircleBackButton));
    await tester.pumpAndSettle();

    expect(find.text('event evt_1'), findsOneWidget);
  });
}
