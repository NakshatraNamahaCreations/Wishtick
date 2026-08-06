import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/wishlist_repository.dart';
import '../domain/wishlist_item.dart';

@immutable
class ItemDetailState {
  const ItemDetailState({this.item, this.error, this.busy = false});

  /// Loaded once when the screen starts; null while loading.
  final WishlistItem? item;
  final String? error;
  final bool busy;

  ItemDetailState copyWith({
    WishlistItem? item,
    String? error,
    bool? busy,
    bool clearError = false,
  }) {
    return ItemDetailState(
      item: item ?? this.item,
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

/// Owns one item's detail screen. Keyed by `(wishlistId, itemId)` — a record,
/// which Dart gives structural equality/hashCode for free, so it works as a
/// family argument with no extra wrapper class.
class ItemDetailController extends Notifier<ItemDetailState> {
  ItemDetailController(this.arg);

  final (String wishlistId, String itemId) arg;

  @override
  ItemDetailState build() => const ItemDetailState();

  WishlistRepository get _repo => ref.read(wishlistRepositoryProvider);

  Future<void> ensureLoaded() async {
    if (state.item != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final item = await _repo.getItem(arg.$1, arg.$2);
      state = state.copyWith(item: item, busy: false);
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    }
  }

  Future<bool> remove() async {
    try {
      await _repo.removeItem(arg.$1, arg.$2);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  /// Recreates this item on [targetWishlistId] and removes it from here —
  /// there is no dedicated "move" endpoint, so this composes the two calls
  /// the backend does offer.
  Future<bool> moveTo(String targetWishlistId) async {
    final current = state.item;
    if (current == null) return false;
    try {
      await _repo.addItem(
        targetWishlistId,
        title: current.title,
        notes: current.notes,
        recipientName: current.recipientName,
        relation: current.relation,
        occasionKey: current.occasionKey,
        productLink: current.productLink,
        priceAmountMinor: current.price.amountMinor,
        category: current.category,
        priority: current.priority,
        importance: current.importance,
        quantity: current.quantity,
        mediaIds: current.imageUrls,
      );
      await _repo.removeItem(arg.$1, arg.$2);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }
}

final itemDetailProvider =
    NotifierProvider.family<
      ItemDetailController,
      ItemDetailState,
      (String, String)
    >(ItemDetailController.new);
