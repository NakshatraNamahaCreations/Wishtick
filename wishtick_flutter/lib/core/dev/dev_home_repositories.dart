import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/discover/data/discover_repository.dart';
import '../../features/discover/domain/discover_feed.dart';
import '../../features/group_gift/domain/group_gift.dart';
import '../../features/home/data/home_repository.dart';
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
        title: "Siya's birthday gift",
        hostId: 'dev-host-1',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
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
