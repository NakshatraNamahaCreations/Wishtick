import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/address.dart';
import '../domain/group_gift.dart';
import '../domain/upcoming_occasion.dart';
import '../domain/wishtick_event.dart';

/// Everything Home's rails read that is not already a wishlist call.
///
/// One repository rather than four: Home is a single screen assembling
/// several small reads, and splitting them would put four providers behind one
/// controller for no gain. The wishlist rail reuses `WishlistRepository`.
class HomeRepository {
  HomeRepository(this._api);

  final ApiClient _api;

  // ── Addresses ─────────────────────────────────────────────────────────────

  Future<List<Address>> listAddresses() async {
    final json = await _api.get<List<dynamic>>('/me/addresses');
    return json
        .map((e) => Address.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Address> createAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String pincode,
    String? country,
    bool? isDefault,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/me/addresses',
      body: {
        'label': label,
        'recipientName': recipientName,
        'phone': phone,
        'line1': line1,
        'line2': ?line2,
        'city': city,
        'state': state,
        'pincode': pincode,
        'country': ?country,
        'isDefault': ?isDefault,
      },
    );
    return Address.fromJson(json);
  }

  Future<Address> updateAddress(
    String id, {
    String? label,
    String? recipientName,
    String? phone,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? pincode,
    bool? isDefault,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/me/addresses/$id',
      body: {
        'label': ?label,
        'recipientName': ?recipientName,
        'phone': ?phone,
        'line1': ?line1,
        'line2': ?line2,
        'city': ?city,
        'state': ?state,
        'pincode': ?pincode,
        'isDefault': ?isDefault,
      },
    );
    return Address.fromJson(json);
  }

  Future<void> removeAddress(String id) =>
      _api.delete<void>('/me/addresses/$id');

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
