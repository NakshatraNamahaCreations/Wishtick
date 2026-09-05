import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/wishlist_repository.dart';
import '../domain/wishlist.dart';

@immutable
class WishlistsState {
  const WishlistsState({
    this.wishlists,
    this.sharedWithMe,
    this.error,
    this.busy = false,
  });

  /// Loaded once when the tab starts; null while loading.
  final List<Wishlist>? wishlists;

  /// Lists other people have shared with you. Separate from [wishlists]
  /// because they are not yours to edit — and because they are the only place
  /// in the app you can gift from.
  final List<Wishlist>? sharedWithMe;

  final String? error;
  final bool busy;

  WishlistsState copyWith({
    List<Wishlist>? wishlists,
    List<Wishlist>? sharedWithMe,
    String? error,
    bool? busy,
    bool clearError = false,
  }) {
    return WishlistsState(
      wishlists: wishlists ?? this.wishlists,
      sharedWithMe: sharedWithMe ?? this.sharedWithMe,
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

/// Owns the "My Wishlist" tab's list — screens are thin views over this.
class WishlistsController extends Notifier<WishlistsState> {
  @override
  WishlistsState build() => const WishlistsState();

  WishlistRepository get _repo => ref.read(wishlistRepositoryProvider);

  /// Loads the list once; safe to call from the screen's init every time it
  /// mounts.
  Future<void> ensureLoaded() async {
    if (state.wishlists != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final wishlists = await _repo.listMine();
      // Shared lists are fetched alongside, not lazily: they are one call and
      // the tab has to know whether to draw the section at all.
      final shared = await _repo.listSharedWithMe();
      state = state.copyWith(
        wishlists: wishlists,
        sharedWithMe: shared,
        busy: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
    }
  }

  /// The new list, or null with [WishlistsState.error] set.
  ///
  /// Returned rather than only added to the state, because a caller may need
  /// exactly this one — the event wizard links the list it just made.
  Future<Wishlist?> create({
    required String title,
    String? description,
    String? occasionLabel,
    required WishlistVisibility visibility,
    String? coverMediaId,
    String? forUserId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final created = await _repo.create(
        title: title,
        description: description,
        occasionLabel: occasionLabel,
        visibility: visibility,
        coverMediaId: coverMediaId,
        forUserId: forUserId,
      );
      state = state.copyWith(
        wishlists: [...?state.wishlists, created],
        busy: false,
      );
      return created;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return null;
    }
  }

  static String _message(ApiException e) => switch (e.code) {
    ApiException.codeNetwork ||
    ApiException.codeTimeout => 'No connection. Check your network and retry.',
    _ => e.message,
  };
}

final wishlistsProvider = NotifierProvider<WishlistsController, WishlistsState>(
  WishlistsController.new,
);
