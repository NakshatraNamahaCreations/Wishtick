import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/discover/data/discover_repository.dart';
import 'package:wishtick_flutter/features/discover/domain/discover_feed.dart';
import 'package:wishtick_flutter/features/discover/presentation/discover_controller.dart';

import '../../helpers/home_fakes.dart';

void main() {
  DiscoverSection section({
    DiscoverSectionKind kind = DiscoverSectionKind.priceBand,
    String title = 'Gifts Under ₹2,000',
  }) => DiscoverSection(
    kind: kind,
    title: title,
    subtitle: null,
    person: null,
    items: const [],
    exploreQuery: const DiscoverExploreQuery(
      category: null,
      minPriceMinor: null,
      maxPriceMinor: 200000,
    ),
  );

  ({ProviderContainer container, FakeDiscoverRepository repo}) build({
    DiscoverFeed? feed,
  }) {
    final repo = FakeDiscoverRepository(feedResult: feed);
    final container = ProviderContainer(
      overrides: [discoverRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo);
  }

  DiscoverController controllerOf(ProviderContainer c) =>
      c.read(discoverProvider.notifier);
  DiscoverState stateOf(ProviderContainer c) => c.read(discoverProvider);

  test('loads the feed once and reuses it', () async {
    final t = build(feed: DiscoverFeed(sections: [section()]));

    await controllerOf(t.container).ensureLoaded();
    await controllerOf(t.container).ensureLoaded();

    expect(t.repo.feedCalls, 1);
    expect(stateOf(t.container).feed?.sections, hasLength(1));
  });

  test('surfaces a failure and recovers on retry', () async {
    final t = build()
      ..repo.failure = const ApiException(
        code: ApiException.codeNetwork,
        message: 'down',
      );

    await controllerOf(t.container).ensureLoaded();
    expect(stateOf(t.container).error, isNotNull);
    expect(stateOf(t.container).feed, isNull);

    t.repo.failure = null;
    t.repo.feedResult = DiscoverFeed(sections: [section()]);
    await controllerOf(t.container).refresh();

    expect(stateOf(t.container).error, isNull);
    expect(stateOf(t.container).feed?.sections, hasLength(1));
  });

  test('an empty feed is a loaded state, not an error', () async {
    final t = build(feed: const DiscoverFeed(sections: []));

    await controllerOf(t.container).ensureLoaded();

    expect(stateOf(t.container).error, isNull);
    expect(stateOf(t.container).feed?.isEmpty, isTrue);
  });

  test('exploreQuery survives the round trip so Explore More can page it', () {
    final parsed = DiscoverSection.fromJson({
      'kind': 'price_band',
      'title': 'Gifts Under ₹2,000',
      'subtitle': null,
      'person': null,
      'items': <dynamic>[],
      'exploreQuery': {
        'category': null,
        'minPriceMinor': null,
        'maxPriceMinor': 200000,
      },
    });

    expect(parsed.kind, DiscoverSectionKind.priceBand);
    expect(parsed.exploreQuery.maxPriceMinor, 200000);
  });

  test('a person shelf keeps who it is for', () {
    final parsed = DiscoverSection.fromJson({
      'kind': 'person_occasion',
      'title': "Gift suggestions for Siya's Birthday",
      'subtitle': 'Best Friend',
      'person': {
        'importantDateId': 'd1',
        'name': 'Siya',
        'relation': 'Best Friend',
        'occasionKey': 'birthday',
        'occasionLabel': 'Birthday',
        'nextOccurrence': '2026-08-07',
        'daysAway': 3,
      },
      'items': <dynamic>[],
      'exploreQuery': {
        'category': 'electronics',
        'minPriceMinor': null,
        'maxPriceMinor': null,
      },
    });

    expect(parsed.kind, DiscoverSectionKind.personOccasion);
    expect(parsed.person?.name, 'Siya');
    expect(parsed.person?.daysAway, 3);
  });
}
