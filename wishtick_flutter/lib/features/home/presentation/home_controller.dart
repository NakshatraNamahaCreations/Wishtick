import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../addresses/data/addresses_repository.dart';
import '../../addresses/domain/address.dart';
import '../../group_gift/domain/group_gift.dart';
import '../../wishlist/data/wishlist_repository.dart';
import '../../wishlist/domain/wishlist.dart';
import '../data/home_repository.dart';
import '../domain/wishtick_event.dart';

/// Home's "In Next 30 days" window.
const kHomeEventWindowDays = 30;

@immutable
class HomeState {
  const HomeState({
    this.addresses,
    this.events,
    this.groupGifts,
    this.wishlists,
    this.error,
    this.busy = false,
  });

  /// Null while loading; each rail resolves independently.
  final List<Address>? addresses;
  final List<WishtickEvent>? events;
  final List<GroupGift>? groupGifts;
  final List<Wishlist>? wishlists;

  final String? error;
  final bool busy;

  /// What the "Where To Deliver?" header shows, or null for "Location Missing".
  Address? get defaultAddress {
    final saved = addresses;
    if (saved == null || saved.isEmpty) return null;
    return saved.firstWhere((a) => a.isDefault, orElse: () => saved.first);
  }

  /// Home shows one chip-in card; an open gift outranks a settled one.
  GroupGift? get featuredGroupGift {
    final gifts = groupGifts;
    if (gifts == null || gifts.isEmpty) return null;
    return gifts.firstWhere(
      (g) => g.status.acceptsContributions,
      orElse: () => gifts.first,
    );
  }

  bool get isLoaded =>
      addresses != null &&
      events != null &&
      groupGifts != null &&
      wishlists != null;

  HomeState copyWith({
    List<Address>? addresses,
    List<WishtickEvent>? events,
    List<GroupGift>? groupGifts,
    List<Wishlist>? wishlists,
    String? error,
    bool? busy,
    bool clearError = false,
  }) {
    return HomeState(
      addresses: addresses ?? this.addresses,
      events: events ?? this.events,
      groupGifts: groupGifts ?? this.groupGifts,
      wishlists: wishlists ?? this.wishlists,
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

/// Assembles Home's rails.
///
/// Each rail is fetched independently and a failure in one does not blank the
/// others — a user with no events should still see their wishlists. Only a
/// total failure surfaces [HomeState.error].
class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeState();

  HomeRepository get _home => ref.read(homeRepositoryProvider);
  WishlistRepository get _wishlists => ref.read(wishlistRepositoryProvider);

  Future<void> ensureLoaded() async {
    if (state.isLoaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, clearError: true);

    final results = await Future.wait([
      _guard(() => ref.read(addressesRepositoryProvider).list()),
      _guard(() => _home.upcomingEvents(withinDays: kHomeEventWindowDays)),
      _guard(() => _home.myGroupGifts(limit: 5)),
      _guard(() => _wishlists.listMine()),
    ]);

    final addresses = results[0] as List<Address>?;
    final events = results[1] as List<WishtickEvent>?;
    final gifts = results[2] as List<GroupGift>?;
    final wishlists = results[3] as List<Wishlist>?;

    // Only if nothing at all loaded is this a screen-level failure.
    final allFailed = results.every((r) => r == null);

    state = HomeState(
      addresses: addresses ?? const [],
      events: events ?? const [],
      groupGifts: gifts ?? const [],
      wishlists: wishlists ?? const [],
      busy: false,
      error: allFailed
          ? 'Could not load. Check your connection and retry.'
          : null,
    );
  }

  /// Runs one rail's fetch, turning a failure into null so the others survive.
  Future<Object?> _guard(Future<Object> Function() fetch) async {
    try {
      return await fetch();
    } on ApiException {
      return null;
    }
  }
}

final homeProvider = NotifierProvider<HomeController, HomeState>(
  HomeController.new,
);
