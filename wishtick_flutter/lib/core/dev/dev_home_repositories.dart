import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/discover/data/discover_repository.dart';
import '../../features/discover/domain/discover_feed.dart';
import '../../features/home/data/home_repository.dart';
import '../../features/home/domain/address.dart';
import '../../features/home/domain/group_gift.dart';
import '../../features/home/domain/upcoming_occasion.dart';
import '../../features/home/domain/wishtick_event.dart';
import 'dev_keys.dart';
import 'dev_repositories.dart';

/// Home's rails, persisted where it matters.
///
/// Upcoming occasions are derived from the very dates
/// [DevOnboardingRepository] saved, so a date entered during onboarding shows
/// up on Home — the same join the real backend makes, just against
/// SharedPreferences.
class DevHomeRepository implements HomeRepository {
  DevHomeRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _latency = Duration(milliseconds: 300);

  // ── Addresses ─────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _readAddresses() =>
      (jsonDecode(_prefs.getString(DevKeys.addresses) ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> _writeAddresses(List<Map<String, dynamic>> rows) =>
      _prefs.setString(DevKeys.addresses, jsonEncode(rows));

  @override
  Future<List<Address>> listAddresses() async {
    await Future<void>.delayed(_latency);
    final rows = _readAddresses()
      ..sort((a, b) {
        final byDefault = ((b['isDefault'] as bool? ?? false) ? 1 : 0)
            .compareTo((a['isDefault'] as bool? ?? false) ? 1 : 0);
        return byDefault != 0
            ? byDefault
            : (a['createdAt'] as String).compareTo(b['createdAt'] as String);
      });
    return rows.map(Address.fromJson).toList();
  }

  @override
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
    await Future<void>.delayed(_latency);
    final rows = _readAddresses();

    // The first address is always the default, like the real service.
    final makeDefault = isDefault == true || rows.isEmpty;
    if (makeDefault) {
      for (final row in rows) {
        row['isDefault'] = false;
      }
    }

    final row = {
      'id': 'dev-addr-${DateTime.now().microsecondsSinceEpoch}',
      'label': label,
      'recipientName': recipientName,
      'phone': phone,
      'line1': line1,
      'line2': line2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country ?? 'India',
      'isDefault': makeDefault,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _writeAddresses([...rows, row]);
    return Address.fromJson(row);
  }

  @override
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
    await Future<void>.delayed(_latency);
    final rows = _readAddresses();
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index == -1) throw StateError('Address $id not found');

    if (isDefault == false && (rows[index]['isDefault'] as bool? ?? false)) {
      throw StateError('Set another address as the default instead');
    }
    if (isDefault == true) {
      for (final row in rows) {
        row['isDefault'] = false;
      }
      rows[index]['isDefault'] = true;
    }

    final row = rows[index];
    if (label != null) row['label'] = label;
    if (recipientName != null) row['recipientName'] = recipientName;
    if (phone != null) row['phone'] = phone;
    if (line1 != null) row['line1'] = line1;
    if (line2 != null) row['line2'] = line2;
    if (city != null) row['city'] = city;
    if (state != null) row['state'] = state;
    if (pincode != null) row['pincode'] = pincode;

    await _writeAddresses(rows);
    return Address.fromJson(row);
  }

  @override
  Future<void> removeAddress(String id) async {
    final rows = _readAddresses();
    final removed = rows.firstWhere(
      (r) => r['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    rows.removeWhere((r) => r['id'] == id);

    // Removing the default promotes the next-oldest, as the real service does.
    if ((removed['isDefault'] as bool? ?? false) && rows.isNotEmpty) {
      rows.sort(
        (a, b) =>
            (a['createdAt'] as String).compareTo(b['createdAt'] as String),
      );
      rows.first['isDefault'] = true;
    }
    await _writeAddresses(rows);
  }

  // ── Upcoming occasions ────────────────────────────────────────────────────

  @override
  Future<List<UpcomingOccasion>> upcomingOccasions({
    int withinDays = 30,
  }) async {
    await Future<void>.delayed(_latency);

    final saved = (_prefs.getStringList(DevKeys.dates) ?? const [])
        .map((row) => jsonDecode(row) as Map<String, dynamic>)
        .toList();

    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);

    final resolved =
        saved
            .map((row) {
              final iso = (row['date'] as String).substring(0, 10);
              final original = DateTime.parse('${iso}T00:00:00Z');

              // This year's occurrence, or next year's if it has passed —
              // the same month/day recurrence the backend applies.
              var next = DateTime.utc(today.year, original.month, original.day);
              if (next.isBefore(today)) {
                next = DateTime.utc(
                  today.year + 1,
                  original.month,
                  original.day,
                );
              }
              final age = next.year - original.year;

              return UpcomingOccasion(
                id: row['id'] as String,
                personName: row['personName'] as String,
                relation: row['relation'] as String,
                occasionKey: row['occasionKey'] as String,
                date: row['date'] as String,
                nextOccurrence: next,
                daysAway: next.difference(today).inDays,
                turningAge: age > 0 ? age : null,
              );
            })
            .where((o) => o.daysAway <= withinDays)
            .toList()
          ..sort((a, b) => a.daysAway.compareTo(b.daysAway));

    return resolved;
  }

  // ── Events ────────────────────────────────────────────────────────────────

  /// Two seeded events matching the Home mock's "Upcoming Events" rail.
  @override
  Future<List<WishtickEvent>> upcomingEvents({int withinDays = 30}) async {
    await Future<void>.delayed(_latency);
    final now = DateTime.now();

    final events = [
      WishtickEvent(
        id: 'dev-event-1',
        title: "Siya's 24th",
        type: EventType.birthday,
        startsAt: now.add(const Duration(days: 2)),
        timezone: 'Asia/Kolkata',
        coverUrl: null,
        isHosting: false,
        description: 'Join us as we make this birthday truly unforgettable.',
        myRsvp: RsvpResponse.pending,
        // Deep-links Home's card straight into the invite screen, the same way
        // `GET /events/invited` hands back the invitee's own token.
        inviteToken: 'dev-invite-1',
      ),
      WishtickEvent(
        id: 'dev-event-2',
        title: "Ananya's 24th",
        type: EventType.birthday,
        startsAt: now.add(const Duration(days: 12)),
        timezone: 'Asia/Kolkata',
        coverUrl: null,
        isHosting: true,
        description: 'Cake, candles and a very long playlist.',
        status: EventStatus.published,
        attendingCount: 14,
      ),
    ];

    return events.where((e) => e.daysAway() <= withinDays).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  // ── Group gifts ───────────────────────────────────────────────────────────

  /// One open gift, at the mock's ₹14,400-of-₹16,000 progress.
  @override
  Future<List<GroupGift>> myGroupGifts({int limit = 10}) async {
    await Future<void>.delayed(_latency);
    return [
      GroupGift(
        id: 'dev-gg-1',
        itemId: 'dev-item-3',
        wishlistId: 'dev-wl-1',
        status: GroupGiftStatus.open,
        targetAmountMinor: 1600000,
        collectedAmountMinor: 1440000,
        currency: 'INR',
        percentFunded: 90,
        contributorCount: 6,
        deadline: DateTime.now().add(const Duration(days: 3)),
        myContributionMinor: 0,
        message: 'Join us as we make this birthday truly unforgettable.',
      ),
    ].take(limit).toList();
  }
}

/// Builds the same three shelf kinds the real feed does, from the dev
/// catalogue — so Discover's layout is exercised without a backend.
class DevDiscoverRepository implements DiscoverRepository {
  DevDiscoverRepository(this._home);

  final DevHomeRepository _home;

  static const _latency = Duration(milliseconds: 300);
  static const _priceBandMaxMinor = 200000;
  static const _premiumMinMinor = 300000;

  @override
  Future<DiscoverFeed> feed() async {
    await Future<void>.delayed(_latency);

    final catalog = DevProductRepository.catalog;
    final upcoming = await _home.upcomingOccasions(withinDays: 60);

    final sections = <DiscoverSection>[
      for (final person in upcoming.take(3))
        DiscoverSection(
          kind: DiscoverSectionKind.personOccasion,
          title:
              "Gift suggestions for ${person.personName}'s "
              '${_occasionLabel(person.occasionKey)}',
          subtitle: person.relation,
          person: DiscoverPerson(
            importantDateId: person.id,
            name: person.personName,
            relation: person.relation,
            occasionKey: person.occasionKey,
            occasionLabel: _occasionLabel(person.occasionKey),
            nextOccurrence: person.nextOccurrence,
            daysAway: person.daysAway,
          ),
          items: catalog.take(4).toList(),
          exploreQuery: const DiscoverExploreQuery(
            category: 'electronics',
            minPriceMinor: null,
            maxPriceMinor: null,
          ),
        ),
      DiscoverSection(
        kind: DiscoverSectionKind.priceBand,
        title: 'Gifts Under ₹2,000',
        subtitle: null,
        person: null,
        items: catalog
            .where((p) => (p.amountMinor ?? 0) <= _priceBandMaxMinor)
            .take(4)
            .toList(),
        exploreQuery: const DiscoverExploreQuery(
          category: null,
          minPriceMinor: null,
          maxPriceMinor: _priceBandMaxMinor,
        ),
      ),
      DiscoverSection(
        kind: DiscoverSectionKind.premium,
        title: 'Premium Picks for You',
        subtitle: null,
        person: null,
        items: catalog
            .where((p) => (p.amountMinor ?? 0) >= _premiumMinMinor)
            .take(4)
            .toList(),
        exploreQuery: const DiscoverExploreQuery(
          category: null,
          minPriceMinor: _premiumMinMinor,
          maxPriceMinor: null,
        ),
      ),
    ];

    // Empty shelves are dropped, matching the real feed.
    return DiscoverFeed(
      sections: sections.where((s) => s.items.isNotEmpty).toList(),
    );
  }

  @override
  Future<DiscoverSection> occasionShelf(String occasionKey) async {
    await Future<void>.delayed(_latency);
    final label = _occasionLabel(occasionKey);
    return DiscoverSection(
      kind: DiscoverSectionKind.personOccasion,
      title: 'Gifts for $label',
      subtitle: null,
      person: null,
      items: DevProductRepository.catalog.take(4).toList(),
      exploreQuery: const DiscoverExploreQuery(
        category: 'electronics',
        minPriceMinor: null,
        maxPriceMinor: null,
      ),
    );
  }

  static String _occasionLabel(String key) => switch (key) {
    'birthday' => 'Birthday',
    'anniversary' => 'Anniversary',
    'wedding' => 'Wedding',
    'housewarming' => 'Housewarming',
    'baby_shower' => 'Baby Shower',
    'rakhi' => 'Rakhi',
    'best_wishes' => 'Best Wishes',
    _ => key,
  };
}
