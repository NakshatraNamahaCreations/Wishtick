import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/addresses/data/addresses_repository.dart';
import 'package:wishtick_flutter/features/home/data/home_repository.dart';
import 'package:wishtick_flutter/features/home/presentation/home_controller.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist_item.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/wishlist_detail_controller.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/wishlists_controller.dart';

import '../../helpers/home_fakes.dart';
import '../../helpers/wishlist_fakes.dart';

void main() {
  ({ProviderContainer container, FakeWishlistRepository repo}) build({
    List<Wishlist>? wishlists,
    List<WishlistItem>? items,
  }) {
    final repo = FakeWishlistRepository(wishlists: wishlists, items: items);
    final container = ProviderContainer(
      overrides: [
        wishlistRepositoryProvider.overrideWithValue(repo),
        // Changing a wishlist refreshes the Wishlist tab and Home, so both of
        // Home's own fetches have to be fakes here.
        homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
        addressesRepositoryProvider.overrideWithValue(
          FakeAddressesRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo);
  }

  WishlistDetailController controllerOf(ProviderContainer c, String id) =>
      c.read(wishlistDetailProvider(id).notifier);
  WishlistDetailState stateOf(ProviderContainer c, String id) =>
      c.read(wishlistDetailProvider(id));

  group('ensureLoaded', () {
    test('loads the wishlist and its items together', () async {
      final t = build(
        wishlists: [buildWishlist(id: 'wl_1', itemCount: 2)],
        items: [
          buildItem(id: 'i1', position: 0),
          buildItem(id: 'i2', position: 1),
        ],
      );

      await controllerOf(t.container, 'wl_1').ensureLoaded();

      final state = stateOf(t.container, 'wl_1');
      expect(state.wishlist?.id, 'wl_1');
      expect(state.items, hasLength(2));
    });
  });

  group('sortBy', () {
    test('reorders items client-side, no extra network call', () async {
      final t = build(
        wishlists: [buildWishlist(id: 'wl_1')],
        items: [
          buildItem(id: 'cheap', amountMinor: 100, position: 0),
          buildItem(id: 'pricey', amountMinor: 999900, position: 1),
        ],
      );
      await controllerOf(t.container, 'wl_1').ensureLoaded();

      controllerOf(t.container, 'wl_1').sortBy(ItemSort.priceHighLow);

      expect(stateOf(t.container, 'wl_1').items!.map((i) => i.id), [
        'pricey',
        'cheap',
      ]);
    });
  });

  group('update', () {
    test('applies the edit and refreshes state', () async {
      final t = build(
        wishlists: [buildWishlist(id: 'wl_1', title: 'Old')],
      );

      final ok = await controllerOf(
        t.container,
        'wl_1',
      ).update(title: 'New Title', visibility: WishlistVisibility.private);

      expect(ok, isTrue);
      expect(stateOf(t.container, 'wl_1').wishlist?.title, 'New Title');
    });
  });

  group('removeItem', () {
    test('drops the item from state on success', () async {
      final t = build(
        wishlists: [buildWishlist(id: 'wl_1')],
        items: [buildItem(id: 'i1')],
      );
      await controllerOf(t.container, 'wl_1').ensureLoaded();

      final ok = await controllerOf(t.container, 'wl_1').removeItem('i1');

      expect(ok, isTrue);
      expect(stateOf(t.container, 'wl_1').items, isEmpty);
    });
  });

  group('archive', () {
    test('calls through to the repository', () async {
      final t = build(wishlists: [buildWishlist(id: 'wl_1')]);

      final ok = await controllerOf(t.container, 'wl_1').archive();

      expect(ok, isTrue);
      expect(t.repo.archiveCalls, ['wl_1']);
    });

    // Reported from the device: delete the list, go back, and it is still
    // there and still opens. The Wishlist tab and Home each fetch once and
    // keep what they got, so nothing told them the row was gone.
    test('takes the wishlist off the lists that were showing it', () async {
      final t = build(
        wishlists: [
          buildWishlist(id: 'wl_1', title: 'Anjana'),
          buildWishlist(id: 'wl_2', title: 'Jay Birthday'),
        ],
      );
      await t.container.read(wishlistsProvider.notifier).ensureLoaded();
      await t.container.read(homeProvider.notifier).ensureLoaded();
      expect(
        t.container.read(wishlistsProvider).wishlists?.map((w) => w.id),
        containsAll(<String>['wl_1', 'wl_2']),
      );

      await controllerOf(t.container, 'wl_1').archive();

      expect(t.container.read(wishlistsProvider).wishlists?.map((w) => w.id), [
        'wl_2',
      ]);
      expect(t.container.read(homeProvider).wishlists?.map((w) => w.id), [
        'wl_2',
      ]);
    });

    // A delete the server refused leaves the row where it is: taking it off
    // the list would say the opposite of what happened.
    test('a refused delete leaves the lists alone', () async {
      final t = build(
        wishlists: [buildWishlist(id: 'wl_1', title: 'Anjana')],
      );
      await t.container.read(wishlistsProvider.notifier).ensureLoaded();
      t.repo.failure = const ApiException(
        code: 'FORBIDDEN',
        message: 'Not yours to delete',
      );

      final ok = await controllerOf(t.container, 'wl_1').archive();

      expect(ok, isFalse);
      expect(t.container.read(wishlistsProvider).wishlists?.map((w) => w.id), [
        'wl_1',
      ]);
    });
  });

  // Same staleness, one edit earlier: a renamed list kept its old name on the
  // tab and on Home until something else reloaded them.
  group('update', () {
    test('carries the new title to the lists that show it', () async {
      final t = build(
        wishlists: [buildWishlist(id: 'wl_1', title: 'Anjana')],
      );
      await t.container.read(wishlistsProvider.notifier).ensureLoaded();
      await controllerOf(t.container, 'wl_1').ensureLoaded();

      await controllerOf(
        t.container,
        'wl_1',
      ).update(title: 'Anjana Birthday', visibility: WishlistVisibility.public);

      expect(
        t.container.read(wishlistsProvider).wishlists?.single.title,
        'Anjana Birthday',
      );
    });
  });
}
