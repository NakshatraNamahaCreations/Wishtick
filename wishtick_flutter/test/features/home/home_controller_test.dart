import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/addresses/data/addresses_repository.dart';
import 'package:wishtick_flutter/features/addresses/domain/address.dart';
import 'package:wishtick_flutter/features/home/data/home_repository.dart';
import 'package:wishtick_flutter/features/home/presentation/home_controller.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';

import '../../helpers/home_fakes.dart';
import '../../helpers/wishlist_fakes.dart';

void main() {
  const down = ApiException(code: ApiException.codeNetwork, message: 'down');

  ({
    ProviderContainer container,
    FakeHomeRepository home,
    FakeAddressesRepository addresses,
    FakeWishlistRepository wishlists,
  })
  build({
    FakeHomeRepository? home,
    FakeAddressesRepository? addresses,
    FakeWishlistRepository? wishlists,
  }) {
    final homeRepo = home ?? FakeHomeRepository();
    final addressRepo = addresses ?? FakeAddressesRepository();
    final wishlistRepo = wishlists ?? FakeWishlistRepository();
    final container = ProviderContainer(
      overrides: [
        homeRepositoryProvider.overrideWithValue(homeRepo),
        addressesRepositoryProvider.overrideWithValue(addressRepo),
        wishlistRepositoryProvider.overrideWithValue(wishlistRepo),
      ],
    );
    addTearDown(container.dispose);
    return (
      container: container,
      home: homeRepo,
      addresses: addressRepo,
      wishlists: wishlistRepo,
    );
  }

  HomeController controllerOf(ProviderContainer c) =>
      c.read(homeProvider.notifier);
  HomeState stateOf(ProviderContainer c) => c.read(homeProvider);

  group('ensureLoaded', () {
    test('fills every rail and does not refetch once loaded', () async {
      final t = build(
        home: FakeHomeRepository(
          events: [buildEvent()],
          groupGifts: [buildGroupGift()],
        ),
        addresses: FakeAddressesRepository(addresses: [buildAddress()]),
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
      expect(t.addresses.listCalls, 1);
    });
  });

  group('partial failure', () {
    test('one dead rail does not blank the others', () async {
      final t = build(
        home: FakeHomeRepository(groupGifts: [buildGroupGift()])
          ..eventFailure = down,
        addresses: FakeAddressesRepository(addresses: [buildAddress()]),
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
          ..eventFailure = down
          ..groupGiftFailure = down,
        addresses: FakeAddressesRepository()..failure = down,
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
        addresses: FakeAddressesRepository(
          addresses: [
            buildAddress(id: 'a1', label: AddressLabel.work, isDefault: false),
            buildAddress(id: 'a2', label: AddressLabel.home, isDefault: true),
          ],
        ),
      );

      await controllerOf(t.container).ensureLoaded();

      expect(stateOf(t.container).defaultAddress?.label, AddressLabel.home);
    });
  });
}
