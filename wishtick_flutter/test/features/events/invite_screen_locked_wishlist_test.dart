import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/events/data/invite_repository.dart';
import 'package:wishtick_flutter/features/events/domain/public_invite.dart';
import 'package:wishtick_flutter/features/events/presentation/invite_screen.dart';

import '../../helpers/gifting_fakes.dart';

/// A wishlist the host put on the event that this guest may not open.
///
/// Usually a surprise list another guest made *for* the host and kept private.
/// The invitation says it exists and nothing more — a row that opens nothing
/// must still say why, or it reads as broken.
void main() {
  Future<void> pump(WidgetTester tester, PublicInvite invite) async {
    tester.view
      ..physicalSize = const Size(393, 1600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/invite',
      routes: [
        GoRoute(
          path: '/invite',
          builder: (_, _) => const InviteScreen(token: 'tok_1'),
        ),
        GoRoute(
          path: '/w/:slug',
          builder: (_, state) =>
              Scaffold(body: Text('opened ${state.pathParameters['slug']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          inviteRepositoryProvider.overrideWithValue(
            FakeInviteRepository()..invite = invite,
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a locked list is named, marked private, and does not open', (
    tester,
  ) async {
    await pump(
      tester,
      buildInvite(
        rsvp: RsvpResponse.yes,
        wishlists: const [
          InviteWishlistLink(
            slug: null,
            title: 'Gifts for Rohan',
            locked: true,
          ),
        ],
      ),
    );

    expect(find.text('Gifts for Rohan'), findsOneWidget);
    expect(find.text('Private wishlist'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await tester.tap(find.text('Gifts for Rohan'));
    await tester.pumpAndSettle();

    // Explained, not navigated.
    expect(find.textContaining('This wishlist is private'), findsOneWidget);
    expect(find.textContaining('opened '), findsNothing);
  });

  // The widget tests build the link directly, so nothing above proves the
  // wire flag survives parsing. If it did not, a locked row would arrive
  // unlocked with a null slug and the tap would throw.
  test('the locked flag and the missing slug survive parsing', () {
    final locked = InviteWishlistLink.fromJson({
      'slug': null,
      'title': 'Gifts for Rohan',
      'locked': true,
    });
    expect(locked.locked, isTrue);
    expect(locked.slug, isNull);

    // Older servers send no flag at all: that is an open row, as before.
    final open = InviteWishlistLink.fromJson({
      'slug': 'open-list',
      'title': 'Open list',
    });
    expect(open.locked, isFalse);
    expect(open.slug, 'open-list');
  });

  testWidgets('an open list still opens', (tester) async {
    await pump(
      tester,
      buildInvite(
        rsvp: RsvpResponse.yes,
        wishlists: const [
          InviteWishlistLink(slug: 'open-list', title: 'Open list'),
        ],
      ),
    );

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await tester.tap(find.text('Open list'));
    await tester.pumpAndSettle();

    expect(find.text('opened open-list'), findsOneWidget);
  });
}
