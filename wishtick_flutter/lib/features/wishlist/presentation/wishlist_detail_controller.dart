import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/wishlist_repository.dart';
import '../domain/wishlist.dart';
import '../domain/wishlist_item.dart';

enum ItemSort {
  position('Position'),
  priceLowHigh('Price: Low to High'),
  priceHighLow('Price: High to Low'),
  name('Name (A-Z)');

  const ItemSort(this.label);

  final String label;

  int Function(WishlistItem, WishlistItem) get comparator => switch (this) {
    ItemSort.position => (a, b) => a.position.compareTo(b.position),
    ItemSort.priceLowHigh => (a, b) => (a.price.amountMinor ?? 0).compareTo(
      b.price.amountMinor ?? 0,
    ),
    ItemSort.priceHighLow => (a, b) => (b.price.amountMinor ?? 0).compareTo(
      a.price.amountMinor ?? 0,
    ),
    ItemSort.name => (a, b) => a.title.toLowerCase().compareTo(
      b.title.toLowerCase(),
    ),
  };
}

@immutable
class WishlistDetailState {
  const WishlistDetailState({
    this.wishlist,
    this.items,
    this.sort = ItemSort.position,
    this.error,
    this.busy = false,
  });

  /// Loaded once when the screen starts; null while loading.
  final Wishlist? wishlist;
  final List<WishlistItem>? items;
  final ItemSort sort;
  final String? error;
  final bool busy;

  WishlistDetailState copyWith({
    Wishlist? wishlist,
    List<WishlistItem>? items,
    ItemSort? sort,
    String? error,
    bool? busy,
    bool clearError = false,
  }) {
    return WishlistDetailState(
      wishlist: wishlist ?? this.wishlist,
      items: items ?? this.items,
      sort: sort ?? this.sort,
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

/// Owns one wishlist's detail screen — the wishlist itself, its items, and
/// this-screen-scoped item/wishlist mutations. List-level create lives on
/// [WishlistsController] instead.
class WishlistDetailController extends Notifier<WishlistDetailState> {
  WishlistDetailController(this.arg);

  /// The wishlist id this instance is scoped to.
  final String arg;

  @override
  WishlistDetailState build() => const WishlistDetailState();

  WishlistRepository get _repo => ref.read(wishlistRepositoryProvider);

  Future<void> ensureLoaded() async {
    if (state.wishlist != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final wishlist = await _repo.getOne(arg);
      final items = await _repo.listItems(arg);
      items.sort(state.sort.comparator);
      state = state.copyWith(wishlist: wishlist, items: items, busy: false);
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    }
  }

  void sortBy(ItemSort sort) {
    final items = state.items;
    if (items == null) return;
    state = state.copyWith(
      sort: sort,
      items: [...items]..sort(sort.comparator),
    );
  }

  Future<bool> update({
    required String title,
    String? description,
    String? occasionLabel,
    required WishlistVisibility visibility,
    String? coverMediaId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final updated = await _repo.update(
        arg,
        title: title,
        description: description,
        occasionLabel: occasionLabel,
        visibility: visibility,
        coverMediaId: coverMediaId,
      );
      state = state.copyWith(wishlist: updated, busy: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  Future<bool> removeItem(String itemId) async {
    try {
      await _repo.removeItem(arg, itemId);
      state = state.copyWith(
        items: state.items?.where((i) => i.id != itemId).toList(),
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  Future<bool> archive() async {
    try {
      await _repo.archive(arg);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }
}

final wishlistDetailProvider =
    NotifierProvider.family<
      WishlistDetailController,
      WishlistDetailState,
      String
    >(WishlistDetailController.new);
