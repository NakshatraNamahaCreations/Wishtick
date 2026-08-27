import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist_participant.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/manage_access_controller.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/manage_access_screen.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/share_wishlist_screen.dart';

import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';

import '../../helpers/wishlist_fakes.dart';
import '../../helpers/wishmates_fakes.dart';

void main() {
  ({ProviderContainer container, FakeWishlistRepository repo}) build() {
    final repo = FakeWishlistRepository();
    final container = ProviderContainer(
      overrides: [wishlistRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo);
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child,
    FakeWishlistRepository repo, {
    FakeWishmatesRepository? mates,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wishlistRepositoryProvider.overrideWithValue(repo),
          // The invite button opens the WishMates picker, so this screen now
          // needs the graph as well as the list.
          wishmatesRepositoryProvider.overrideWithValue(
            mates ?? FakeWishmatesRepository(mates: const []),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Visibility meaning', () {
    // The whole feature turns on this: the backend's access matrix grants a
    // link holder nothing on a private or event-only list.
    test('a link only admits anyone on public and invite-only lists', () {
      expect(WishlistVisibility.public.linkGrantsAccess, isTrue);
      expect(WishlistVisibility.inviteOnly.linkGrantsAccess, isTrue);
      expect(WishlistVisibility.private.linkGrantsAccess, isFalse);
      expect(WishlistVisibility.eventOnly.linkGrantsAccess, isFalse);
    });
  });

  group('ManageAccessController', () {
    test('ensureLoaded fetches the guest list once', () async {
      final t = build();
      t.repo.participants.add(
        WishlistParticipant(
          id: 'p1',
          userId: 'u1',
          name: 'Rohan',
          role: ParticipantRole.viewer,
          state: ParticipantState.accepted,
          createdAt: DateTime(2026, 6, 1),
        ),
      );

      final controller = t.container.read(
        manageAccessProvider('wl_1').notifier,
      );
      await controller.ensureLoaded();
      await controller.ensureLoaded();

      expect(
        t.container.read(manageAccessProvider('wl_1')).participants,
        hasLength(1),
      );
    });

    test('inviteWishmate appends the row with the role it was given', () async {
      final t = build();
      final controller = t.container.read(
        manageAccessProvider('wl_1').notifier,
      );
      await controller.ensureLoaded();

      final ok = await controller.inviteWishmate(
        'u_friend',
        role: ParticipantRole.contributor,
      );

      expect(ok, isTrue);
      expect(t.repo.addParticipantCalls.single.userId, 'u_friend');
      // The chat role has to survive the trip: granting viewer instead would
      // silently leave them out of the conversation they were added for.
      expect(
        t.repo.addParticipantCalls.single.role,
        ParticipantRole.contributor,
      );
      final state = t.container.read(manageAccessProvider('wl_1'));
      expect(state.participants, hasLength(1));
      // A WishMate has an account already, so there is nothing left to claim.
      expect(state.participants!.single.isPending, isFalse);
      expect(state.error, isNull);
    });

    test('an empty user id is refused before it reaches the server', () async {
      final t = build();
      final controller = t.container.read(
        manageAccessProvider('wl_1').notifier,
      );
      await controller.ensureLoaded();

      expect(await controller.inviteWishmate(''), isFalse);
      expect(t.repo.addParticipantCalls, isEmpty);
    });

    test(
      'a refused invite keeps the server\'s reason and clears busy',
      () async {
        final t = build();
        final controller = t.container.read(
          manageAccessProvider('wl_1').notifier,
        );
        await controller.ensureLoaded();
        t.repo.failure = const ApiException(
          code: 'PARTICIPANT_ALREADY_EXISTS',
          message: 'This person already has access to the wishlist',
          statusCode: 409,
        );

        final ok = await controller.inviteWishmate('u_friend');

        expect(ok, isFalse);
        final state = t.container.read(manageAccessProvider('wl_1'));
        expect(state.error, 'This person already has access to the wishlist');
        expect(state.busy, isFalse);
      },
    );

    test('revoke drops the row without a refetch', () async {
      final t = build();
      final controller = t.container.read(
        manageAccessProvider('wl_1').notifier,
      );
      await controller.ensureLoaded();
      await controller.inviteWishmate('u_friend');
      final id = t.container
          .read(manageAccessProvider('wl_1'))
          .participants!
          .single
          .id;

      await controller.revoke(id);

      expect(t.repo.revokeParticipantCalls, [id]);
      expect(
        t.container.read(manageAccessProvider('wl_1')).participants,
        isEmpty,
      );
    });
  });

  group('ManageAccessScreen', () {
    testWidgets('a private list says the link is not enough', (tester) async {
      final repo = FakeWishlistRepository();
      await pump(
        tester,
        ManageAccessScreen(
          wishlist: buildWishlist(visibility: WishlistVisibility.private),
        ),
        repo,
      );

      expect(find.text('This list is Private'), findsOneWidget);
      expect(
        find.textContaining('Sharing the link is not enough'),
        findsOneWidget,
      );
      expect(find.text('Only you can see this list.'), findsOneWidget);
    });

    testWidgets('picking a WishMate adds them to the access list', (
      tester,
    ) async {
      final repo = FakeWishlistRepository();
      await pump(
        tester,
        ManageAccessScreen(
          wishlist: buildWishlist(visibility: WishlistVisibility.private),
        ),
        repo,
        mates: FakeWishmatesRepository(
          mates: [buildWishmate(userId: 'u_9', displayName: 'Rohan Prasad')],
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Choose WishMates'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rohan Prasad'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Send to'));
      await tester.pumpAndSettle();

      expect(repo.addParticipantCalls.single.userId, 'u_9');

      // A successful send now raises a confirmation over the sheet for two
      // seconds, and it takes no taps while it is up. Waiting it out is what a
      // user does too; tapping through it is not offered.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Dismiss the sheet — the screen refetches on the way out. The sheet
      // adds people through the repository directly, so without that refetch
      // the list underneath still says nobody has access, and the host is
      // looking at a screen that contradicts what they just did.
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      expect(find.text('Someone on Wishtick'), findsOneWidget);
    });

    testWidgets('the chat toggle decides what the picker grants', (
      tester,
    ) async {
      final repo = FakeWishlistRepository();
      await pump(
        tester,
        ManageAccessScreen(
          wishlist: buildWishlist(visibility: WishlistVisibility.private),
        ),
        repo,
        mates: FakeWishmatesRepository(
          mates: [buildWishmate(userId: 'u_9', displayName: 'Rohan Prasad')],
        ),
      );

      // Turned on BEFORE the sheet opens, which is the only order that can
      // work: the target is built when the button is tapped.
      await tester.tap(find.text('Let them join the chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Choose WishMates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rohan Prasad'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Send to'));
      await tester.pumpAndSettle();

      expect(repo.addParticipantCalls.single.role, ParticipantRole.contributor);

      // Let the sent confirmation run its course, so the test does not end
      // with its timer still pending.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('the chat toggle is absent when the list has no chat', (
      tester,
    ) async {
      final repo = FakeWishlistRepository();
      await pump(
        tester,
        ManageAccessScreen(wishlist: buildWishlist(chatEnabled: false)),
        repo,
      );

      expect(find.text('Let them join the chat'), findsNothing);
    });
  });

  group('ShareWishlistScreen', () {
    testWidgets('a private list is told its link will not work', (
      tester,
    ) async {
      final repo = FakeWishlistRepository();
      await pump(
        tester,
        ShareWishlistScreen(
          wishlist: buildWishlist(
            visibility: WishlistVisibility.private,
            share: null,
          ),
        ),
        repo,
      );

      expect(find.text('A link won’t open this list'), findsOneWidget);
      expect(find.text('Invite people'), findsOneWidget);
      // The dead grid is gone, and no slug was minted for it.
      expect(find.text('Share Via'), findsNothing);
      expect(find.text('Copy link'), findsNothing);
      expect(repo.configureShareCalls, isEmpty);
    });

    testWidgets('a public list still gets the share grid', (tester) async {
      final repo = FakeWishlistRepository();
      await pump(
        tester,
        ShareWishlistScreen(
          // Never shared before, so the screen has to mint a slug.
          wishlist: buildWishlist(
            visibility: WishlistVisibility.public,
            share: null,
          ),
        ),
        repo,
      );

      expect(find.text('Share Via'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.textContaining('A link won’t open'), findsNothing);
      expect(repo.configureShareCalls, hasLength(1));
    });
  });
}
