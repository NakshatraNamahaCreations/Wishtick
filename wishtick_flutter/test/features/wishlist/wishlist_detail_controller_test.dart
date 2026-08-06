import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist_item.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/wishlist_detail_controller.dart';

import '../../helpers/wishlist_fakes.dart';

void main() {
  ({ProviderContainer container, FakeWishlistRepository repo}) build({
    List<Wishlist>? wishlists,
    List<WishlistItem>? items,
  }) {
    final repo = FakeWishlistRepository(wishlists: wishlists, items: items);
    final container = ProviderContainer(
      overrides: [wishlistRepositoryProvider.overrideWithValue(repo)],
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
  });
}
