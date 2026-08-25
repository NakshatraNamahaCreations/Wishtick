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

import '../../helpers/wishlist_fakes.dart';

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
    FakeWishlistRepository repo,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wishlistRepositoryProvider.overrideWithValue(repo)],
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
          inviteEmail: null,
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

    test('inviteByEmail normalises the address and appends the row', () async {
      final t = build();
      final controller = t.container.read(
        manageAccessProvider('wl_1').notifier,
      );
      await controller.ensureLoaded();

      final ok = await controller.inviteByEmail('  Friend@Example.COM ');

      expect(ok, isTrue);
      expect(t.repo.addParticipantCalls.single.email, 'friend@example.com');
      final state = t.container.read(manageAccessProvider('wl_1'));
      expect(state.participants, hasLength(1));
      // Nobody has claimed the address yet, so it stays pending.
      expect(state.participants!.single.isPending, isTrue);
      expect(state.error, isNull);
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

        final ok = await controller.inviteByEmail('friend@example.com');

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
      await controller.inviteByEmail('friend@example.com');
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

    testWidgets('inviting an email adds a pending row', (tester) async {
      final repo = FakeWishlistRepository();
      await pump(
        tester,
        ManageAccessScreen(
          wishlist: buildWishlist(visibility: WishlistVisibility.private),
        ),
        repo,
      );

      await tester.enterText(find.byType(TextField), 'friend@example.com');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Invite'));
      await tester.pumpAndSettle();

      expect(repo.addParticipantCalls.single.email, 'friend@example.com');
      expect(find.text('friend@example.com'), findsWidgets);
      expect(find.text('Invited'), findsOneWidget);
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
