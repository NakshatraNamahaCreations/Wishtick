import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../group_gift/domain/group_gift.dart';
import '../domain/upcoming_occasion.dart';
import '../domain/wishtick_event.dart';

/// Everything Home's rails read that is not already a wishlist call.
///
/// One repository rather than four: Home is a single screen assembling
/// several small reads, and splitting them would put four providers behind one
/// controller for no gain. The wishlist rail reuses `WishlistRepository`, and
/// the delivery address rail reuses `AddressesRepository` — the address book is
/// a Profile screen with its own CRUD surface, so Home only ever reads it.
class HomeRepository {
  HomeRepository(this._api);

  final ApiClient _api;

  // ── Upcoming occasions ────────────────────────────────────────────────────

  /// Saved important dates whose next yearly occurrence is near.
  Future<List<UpcomingOccasion>> upcomingOccasions({
    int withinDays = 30,
  }) async {
    final json = await _api.get<List<dynamic>>(
      '/me/important-dates/upcoming',
      query: {'withinDays': withinDays},
    );
    return json
        .map((e) => UpcomingOccasion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Events ────────────────────────────────────────────────────────────────

  /// Hosted and invited events merged into one upcoming-first rail.
  ///
  /// Neither endpoint takes a date filter, so "upcoming" is applied here —
  /// the same client-side sort the backend's own docs point to.
  Future<List<WishtickEvent>> upcomingEvents({int withinDays = 30}) async {
    final results = await Future.wait([
      _api.get<List<dynamic>>('/events/mine'),
      _api.get<List<dynamic>>('/events/invited'),
    ]);

    final events = [
      ...results[0].map(
        (e) => WishtickEvent.fromHosted(e as Map<String, dynamic>),
      ),
      ...results[1].map(
        (e) => WishtickEvent.fromInvited(e as Map<String, dynamic>),
      ),
    ];

    final upcoming = events.where((e) {
      final days = e.daysAway();
      return days >= 0 && days <= withinDays;
    }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return upcoming;
  }

  // ── Group gifts ───────────────────────────────────────────────────────────

  Future<List<GroupGift>> myGroupGifts({int limit = 10}) async {
    final json = await _api.get<List<dynamic>>(
      '/group-gifts/mine',
      query: {'limit': limit},
    );
    return json
        .map((e) => GroupGift.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});
