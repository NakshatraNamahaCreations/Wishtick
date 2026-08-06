import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/home/data/home_repository.dart';
import 'package:wishtick_flutter/features/home/domain/group_gift.dart';
import 'package:wishtick_flutter/features/home/presentation/home_controller.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';

import '../../helpers/home_fakes.dart';
import '../../helpers/wishlist_fakes.dart';

void main() {
  const down = ApiException(code: ApiException.codeNetwork, message: 'down');

  ({
    ProviderContainer container,
    FakeHomeRepository home,
    FakeWishlistRepository wishlists,
  })
  build({FakeHomeRepository? home, FakeWishlistRepository? wishlists}) {
    final homeRepo = home ?? FakeHomeRepository();
    final wishlistRepo = wishlists ?? FakeWishlistRepository();
    final container = ProviderContainer(
      overrides: [
        homeRepositoryProvider.overrideWithValue(homeRepo),
        wishlistRepositoryProvider.overrideWithValue(wishlistRepo),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, home: homeRepo, wishlists: wishlistRepo);
  }

  HomeController controllerOf(ProviderContainer c) =>
      c.read(homeProvider.notifier);
  HomeState stateOf(ProviderContainer c) => c.read(homeProvider);

  group('ensureLoaded', () {
    test('fills every rail and does not refetch once loaded', () async {
      final t = build(
        home: FakeHomeRepository(
          addresses: [buildAddress()],
          events: [buildEvent()],
          groupGifts: [buildGroupGift()],
        ),
        wishlists: FakeWishlistRepository(wishlists: [buildWishlist()]),
      );

      await controllerOf(t.container).ensureLoaded();
      await controllerOf(t.container).ensureLoaded();

      final state = stateOf(t.container);
      expect(state.isLoaded, isTrue);
      expect(state.addresses, hasLength(1));
      expect(state.events, hasLength(1));
      expect(state.groupGifts, hasLength(1));
      expect(state.wishlists, hasLength(1));
      expect(t.home.listAddressCalls, 1);
    });
  });

  group('partial failure', () {
    test('one dead rail does not blank the others', () async {
      final t = build(
        home: FakeHomeRepository(
          addresses: [buildAddress()],
          groupGifts: [buildGroupGift()],
        )..eventFailure = down,
        wishlists: FakeWishlistRepository(wishlists: [buildWishlist()]),
      );

      await controllerOf(t.container).ensureLoaded();

      final state = stateOf(t.container);
      expect(state.events, isEmpty);
      // The rails that did load are still there, and no screen-level error.
      expect(state.addresses, hasLength(1));
      expect(state.wishlists, hasLength(1));
      expect(state.error, isNull);
    });

    test('surfaces an error only when every rail fails', () async {
      final t = build(
        home: FakeHomeRepository()
          ..addressFailure = down
          ..eventFailure = down
          ..groupGiftFailure = down,
        wishlists: FakeWishlistRepository()..failure = down,
      );

      await controllerOf(t.container).ensureLoaded();

      expect(stateOf(t.container).error, isNotNull);
    });
  });

  group('defaultAddress', () {
    test(
      'is null when nothing is saved, so Home says "Location Missing"',
      () async {
        final t = build();
        await controllerOf(t.container).ensureLoaded();
        expect(stateOf(t.container).defaultAddress, isNull);
      },
    );

    test('picks the flagged address, not merely the first', () async {
      final t = build(
        home: FakeHomeRepository(
          addresses: [
            buildAddress(id: 'a1', label: 'Work', isDefault: false),
            buildAddress(id: 'a2', label: 'Home', isDefault: true),
          ],
        ),
      );

      await controllerOf(t.container).ensureLoaded();

      expect(stateOf(t.container).defaultAddress?.label, 'Home');
    });
  });

  group('featuredGroupGift', () {
    test('prefers a gift still taking money over a settled one', () async {
      final t = build(
        home: FakeHomeRepository(
          groupGifts: [
            buildGroupGift(id: 'done', status: GroupGiftStatus.fulfilled),
            buildGroupGift(id: 'open', status: GroupGiftStatus.open),
          ],
        ),
      );

      await controllerOf(t.container).ensureLoaded();

      expect(stateOf(t.container).featuredGroupGift?.id, 'open');
    });

    test('falls back to the newest when none are open', () async {
      final t = build(
        home: FakeHomeRepository(
          groupGifts: [
            buildGroupGift(id: 'done', status: GroupGiftStatus.fulfilled),
          ],
        ),
      );

      await controllerOf(t.container).ensureLoaded();

      expect(stateOf(t.container).featuredGroupGift?.id, 'done');
    });

    test('is null when there are none, so the card is hidden', () async {
      final t = build();
      await controllerOf(t.container).ensureLoaded();
      expect(stateOf(t.container).featuredGroupGift, isNull);
    });
  });
}
