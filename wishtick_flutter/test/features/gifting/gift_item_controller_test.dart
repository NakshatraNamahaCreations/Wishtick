import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/gifting/data/gifting_repository.dart';
import 'package:wishtick_flutter/features/gifting/domain/gift.dart';
import 'package:wishtick_flutter/features/gifting/presentation/gift_item_controller.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist_item.dart';

import '../../helpers/gifting_fakes.dart';
import '../../helpers/wishlist_fakes.dart';

void main() {
  late FakeWishlistRepository wishlists;
  late FakeGiftingRepository gifting;
  late ProviderContainer container;

  const arg = ('wl_1', 'item_1');

  ProviderContainer build() => ProviderContainer(
    overrides: [
      wishlistRepositoryProvider.overrideWithValue(wishlists),
      giftingRepositoryProvider.overrideWithValue(gifting),
    ],
  );

  setUp(() {
    wishlists = FakeWishlistRepository(
      wishlists: [buildWishlist(id: 'wl_1', access: sharedAccess)],
      items: [buildItem(id: 'item_1')],
    );
    gifting = FakeGiftingRepository();
    container = build();
  });

  tearDown(() => container.dispose());

  test('loads the item, the wishlist and any hold of your own', () async {
    await container.read(giftItemProvider(arg).notifier).ensureLoaded();
    final state = container.read(giftItemProvider(arg));

    expect(state.item?.id, 'item_1');
    expect(state.canGift, isTrue);
    expect(state.myGift, isNull);
    expect(gifting.onHoldCalls, 1);
  });

  test('an item on your own list offers nothing to gift', () async {
    wishlists.wishlists[0] = buildWishlist(id: 'wl_1');

    await container.read(giftItemProvider(arg).notifier).ensureLoaded();

    expect(container.read(giftItemProvider(arg)).canGift, isFalse);
  });

  test('reserving records the gift and re-reads the item', () async {
    final notifier = container.read(giftItemProvider(arg).notifier);
    await notifier.ensureLoaded();

    final gift = await notifier.reserve();

    expect(gift, isNotNull);
    expect(gifting.reserveCalls, ['item_1']);
    expect(container.read(giftItemProvider(arg)).isReservedByMe, isTrue);
  });

  test('a lost race reads as someone else getting there first', () async {
    gifting.reserveFailure = const ApiException(
      code: 'ITEM_ALREADY_CLAIMED',
      message: 'Item already claimed',
      statusCode: 409,
    );
    final notifier = container.read(giftItemProvider(arg).notifier);
    await notifier.ensureLoaded();

    expect(await notifier.reserve(), isNull);
    expect(
      container.read(giftItemProvider(arg)).error,
      'Someone else just reserved this gift.',
    );
  });

  test(
    'ITEM_NOT_AVAILABLE says the same thing as ITEM_ALREADY_CLAIMED',
    () async {
      gifting.reserveFailure = const ApiException(
        code: 'ITEM_NOT_AVAILABLE',
        message: 'Item is not available',
        statusCode: 409,
      );
      final notifier = container.read(giftItemProvider(arg).notifier);
      await notifier.ensureLoaded();
      await notifier.reserve();

      expect(
        container.read(giftItemProvider(arg)).error,
        'Someone else just reserved this gift.',
      );
    },
  );

  test('releasing clears your hold', () async {
    final notifier = container.read(giftItemProvider(arg).notifier);
    await notifier.ensureLoaded();
    await notifier.reserve();

    expect(await notifier.release(), isTrue);
    expect(container.read(giftItemProvider(arg)).myGift, isNull);
    expect(gifting.releaseCalls, ['item_1']);
  });

  test('marking purchased moves the gift on', () async {
    final notifier = container.read(giftItemProvider(arg).notifier);
    await notifier.ensureLoaded();
    final reserved = await notifier.reserve();

    final purchased = await notifier.markPurchased(note: 'Happy birthday!');

    expect(purchased?.status, GiftStatus.purchased);
    expect(gifting.purchaseCalls, [reserved!.id]);
    expect(container.read(giftItemProvider(arg)).isPurchasedByMe, isTrue);
  });

  test('an item held by someone else is claimed, but not by you', () async {
    wishlists.items[0] = buildItem(
      id: 'item_1',
      status: WishlistItemStatus.reserved,
    );

    await container.read(giftItemProvider(arg).notifier).ensureLoaded();
    final state = container.read(giftItemProvider(arg));

    expect(state.claimedByOther, isTrue);
    expect(state.myGift, isNull);
  });

  test('your own hold on a claimed item is not "claimed by other"', () async {
    gifting.gifts.add(buildGift(itemId: 'item_1'));
    wishlists.items[0] = buildItem(
      id: 'item_1',
      status: WishlistItemStatus.reserved,
    );

    await container.read(giftItemProvider(arg).notifier).ensureLoaded();
    final state = container.read(giftItemProvider(arg));

    expect(state.claimedByOther, isFalse);
    expect(state.isReservedByMe, isTrue);
  });
}
