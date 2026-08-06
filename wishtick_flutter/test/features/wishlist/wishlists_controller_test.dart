import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/wishlists_controller.dart';

import '../../helpers/wishlist_fakes.dart';

void main() {
  ({ProviderContainer container, FakeWishlistRepository repo}) build({
    List<Wishlist>? seed,
  }) {
    final repo = FakeWishlistRepository(wishlists: seed);
    final container = ProviderContainer(
      overrides: [wishlistRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo);
  }

  WishlistsController controllerOf(ProviderContainer c) =>
      c.read(wishlistsProvider.notifier);
  WishlistsState stateOf(ProviderContainer c) => c.read(wishlistsProvider);

  group('ensureLoaded', () {
    test('loads once and reuses the result', () async {
      final t = build(seed: [buildWishlist()]);
      await controllerOf(t.container).ensureLoaded();
      await controllerOf(t.container).ensureLoaded();

      expect(t.repo.listMineCalls, 1);
      expect(stateOf(t.container).wishlists, hasLength(1));
    });

    test('surfaces a load failure and can retry', () async {
      final t = build()
        ..repo.failure = const ApiException(
          code: ApiException.codeNetwork,
          message: 'down',
        );
      await controllerOf(t.container).ensureLoaded();
      expect(stateOf(t.container).error, isNotNull);

      t.repo.failure = null;
      t.repo.wishlists.add(buildWishlist());
      await controllerOf(t.container).refresh();

      expect(stateOf(t.container).wishlists, hasLength(1));
      expect(stateOf(t.container).error, isNull);
    });
  });

  group('create', () {
    test('appends the created wishlist to state', () async {
      final t = build(
        seed: [buildWishlist(id: 'wl_1', title: 'Existing')],
      );
      await controllerOf(t.container).ensureLoaded();

      final ok = await controllerOf(
        t.container,
      ).create(title: 'New Wishlist', visibility: WishlistVisibility.public);

      expect(ok, isTrue);
      expect(stateOf(t.container).wishlists?.map((w) => w.title), [
        'Existing',
        'New Wishlist',
      ]);
    });

    test('surfaces a create failure without touching state', () async {
      final t = build(
        seed: [buildWishlist(id: 'wl_1', title: 'Existing')],
      );
      await controllerOf(t.container).ensureLoaded();
      t.repo.failure = const ApiException(
        code: ApiException.codeValidationFailed,
        message: 'bad',
      );

      final ok = await controllerOf(
        t.container,
      ).create(title: 'New Wishlist', visibility: WishlistVisibility.public);

      expect(ok, isFalse);
      expect(stateOf(t.container).error, isNotNull);
      expect(stateOf(t.container).wishlists, hasLength(1));
    });
  });
}
