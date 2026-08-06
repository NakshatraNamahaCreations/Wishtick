import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../wishlist/data/wishlist_repository.dart';
import '../../wishlist/domain/wishlist.dart';
import '../../wishlist/domain/wishlist_item.dart';
import '../data/gifting_repository.dart';
import '../domain/gift.dart';

@immutable
class GiftItemState {
  const GiftItemState({
    this.item,
    this.wishlist,
    this.myGift,
    this.error,
    this.busy = false,
  });

  final WishlistItem? item;
  final Wishlist? wishlist;

  /// Your own gift on this item, if you already have one. Null both when the
  /// item is free and when *someone else* holds it — the server never says who,
  /// so the difference is [WishlistItem.status], not this.
  final Gift? myGift;

  final String? error;
  final bool busy;

  /// The wishlist's access block is what decides this, not the item: the owner
  /// of a list is always refused, and a link holder who is not signed in has
  /// no account to attribute a gift to.
  bool get canGift => wishlist?.access.canGift ?? false;

  /// Held by someone, and not by you.
  bool get claimedByOther =>
      myGift == null && (item?.status.isClaimed ?? false);

  bool get isReservedByMe => myGift?.status == GiftStatus.reserved;

  bool get isPurchasedByMe =>
      myGift != null &&
      const {
        GiftStatus.purchased,
        GiftStatus.fulfilled,
        GiftStatus.completed,
      }.contains(myGift!.status);

  GiftItemState copyWith({
    WishlistItem? item,
    Wishlist? wishlist,
    Gift? myGift,
    String? error,
    bool? busy,
    bool clearError = false,
    bool clearGift = false,
  }) {
    return GiftItemState(
      item: item ?? this.item,
      wishlist: wishlist ?? this.wishlist,
      myGift: clearGift ? null : (myGift ?? this.myGift),
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

/// Owns one item on someone else's wishlist — Figma `291:1170`.
///
/// Keyed by `(wishlistId, itemId)`, mirroring the owner-side item controller.
class GiftItemController extends Notifier<GiftItemState> {
  GiftItemController(this.arg);

  final (String wishlistId, String itemId) arg;

  @override
  GiftItemState build() => const GiftItemState();

  WishlistRepository get _wishlists => ref.read(wishlistRepositoryProvider);
  GiftingRepository get _gifting => ref.read(giftingRepositoryProvider);

  Future<void> ensureLoaded() async {
    if (state.item != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final wishlist = await _wishlists.getOne(arg.$1);
      final item = await _wishlists.getItem(arg.$1, arg.$2);

      // There is no `GET /gifts/:id`, and no route from an item to its gift,
      // so your own hold is found by scanning the gifts you are holding. The
      // list is small by construction — it is only what you have not yet
      // handed over.
      final onHold = await _gifting.listOnHold();
      final mine = onHold.where((g) => g.itemId == arg.$2).toList();

      state = GiftItemState(
        item: item,
        wishlist: wishlist,
        myGift: mine.isEmpty ? null : mine.first,
      );
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    }
  }

  /// Claims the item. Returns the gift, or null if it failed — the reason is
  /// on [GiftItemState.error].
  Future<Gift?> reserve({bool hiddenFromOwner = true}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final gift = await _gifting.reserve(
        arg.$2,
        hiddenFromOwner: hiddenFromOwner,
      );
      state = state.copyWith(myGift: gift, busy: false);
      // Pulls the item's new status back, so the screen stops offering to
      // reserve something you now hold.
      await _reloadItem();
      return gift;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _reserveMessage(e));
      return null;
    }
  }

  Future<bool> release() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _gifting.release(arg.$2);
      state = state.copyWith(busy: false, clearGift: true);
      await _reloadItem();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  /// Records that the purchase went through at the merchant.
  ///
  /// Wishtick takes no payment, so nothing here can observe a sale — this is
  /// the gifter telling us, and it is what mints the order.
  Future<Gift?> markPurchased({String? note}) async {
    final gift = state.myGift;
    if (gift == null) return null;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final updated = await _gifting.purchase(gift.id, note: note);
      state = state.copyWith(myGift: updated, busy: false);
      await _reloadItem();
      return updated;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return null;
    }
  }

  Future<void> _reloadItem() async {
    try {
      final item = await _wishlists.getItem(arg.$1, arg.$2);
      state = state.copyWith(item: item);
    } on ApiException {
      // The item's badge being one refresh stale is not worth replacing a
      // successful reservation with an error.
    }
  }

  /// Both 409s mean the same thing to a person standing in front of the
  /// screen, and neither server message says it plainly.
  static String _reserveMessage(ApiException e) => switch (e.code) {
    'ITEM_NOT_AVAILABLE' ||
    'ITEM_ALREADY_CLAIMED' => 'Someone else just reserved this gift.',
    'CANNOT_GIFT_OWN_ITEM' => 'You cannot gift an item on your own wishlist.',
    _ => e.message,
  };
}

final giftItemProvider =
    NotifierProvider.family<
      GiftItemController,
      GiftItemState,
      (String, String)
    >(GiftItemController.new);
