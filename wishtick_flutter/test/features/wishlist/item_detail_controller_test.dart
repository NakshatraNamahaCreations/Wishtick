import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist_item.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/item_detail_controller.dart';

import '../../helpers/wishlist_fakes.dart';

void main() {
  ({ProviderContainer container, FakeWishlistRepository repo}) build({
    List<WishlistItem>? items,
  }) {
    final repo = FakeWishlistRepository(items: items);
    final container = ProviderContainer(
      overrides: [wishlistRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo);
  }

  ItemDetailController controllerOf(
    ProviderContainer c,
    (String, String) arg,
  ) => c.read(itemDetailProvider(arg).notifier);
  ItemDetailState stateOf(ProviderContainer c, (String, String) arg) =>
      c.read(itemDetailProvider(arg));

  group('ensureLoaded', () {
    test('fetches the single item by id', () async {
      final t = build(
        items: [buildItem(id: 'i1', title: 'Sneakers')],
      );

      await controllerOf(t.container, ('wl_1', 'i1')).ensureLoaded();

      expect(stateOf(t.container, ('wl_1', 'i1')).item?.title, 'Sneakers');
    });
  });

  group('remove', () {
    test('deletes remotely and reports success', () async {
      final t = build(items: [buildItem(id: 'i1')]);

      final ok = await controllerOf(t.container, ('wl_1', 'i1')).remove();

      expect(ok, isTrue);
      expect(t.repo.removeItemCalls, ['i1']);
    });
  });

  group('moveTo', () {
    test(
      'recreates the item on the target wishlist and removes it from the source',
      () async {
        final t = build(
          items: [
            buildItem(
              id: 'i1',
              title: 'Sneakers',
              recipientName: 'Ananya',
              amountMinor: 5000,
            ),
          ],
        );
        await controllerOf(t.container, ('wl_source', 'i1')).ensureLoaded();

        final ok = await controllerOf(t.container, (
          'wl_source',
          'i1',
        )).moveTo('wl_target');

        expect(ok, isTrue);
        expect(t.repo.addItemCalls, ['Sneakers']);
        expect(t.repo.removeItemCalls, ['i1']);
      },
    );

    test('does nothing when the item was never loaded', () async {
      final t = build();

      final ok = await controllerOf(t.container, (
        'wl_source',
        'missing',
      )).moveTo('wl_target');

      expect(ok, isFalse);
      expect(t.repo.addItemCalls, isEmpty);
    });
  });
}
