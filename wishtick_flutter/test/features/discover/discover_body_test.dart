import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_colors.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/discover/data/discover_repository.dart';
import 'package:wishtick_flutter/features/discover/domain/discover_feed.dart';
import 'package:wishtick_flutter/features/discover/presentation/discover_body.dart';
import 'package:wishtick_flutter/features/wishlist/domain/product.dart';

import '../../helpers/home_fakes.dart';

/// `280:131` — the Discover feed as a whole: heading style/emphasis and
/// full-bleed background dispatched by [DiscoverSectionKind], on top of the
/// per-shelf widgets already covered by their own test files.
void main() {
  NormalizedProduct product(String id) => NormalizedProduct(
    provider: 'fixture',
    externalId: id,
    title: 'Snake Plant',
    description: null,
    imageUrls: const [],
    productUrl: 'https://example.test/$id',
    affiliateUrl: null,
    amountMinor: 79900,
    listPriceMinor: null,
    currency: 'INR',
    merchant: null,
    category: null,
    inStock: true,
  );

  DiscoverSection personSection() => DiscoverSection(
    kind: DiscoverSectionKind.personOccasion,
    title: "Gift suggestions for Siya's Birthday",
    subtitle: 'Best Friend',
    person: DiscoverPerson(
      importantDateId: 'd1',
      name: 'Siya',
      relation: 'Best Friend',
      occasionKey: 'birthday',
      occasionLabel: 'Birthday',
      nextOccurrence: DateTime(2026, 7, 26),
      daysAway: 3,
    ),
    items: [product('p1')],
    exploreQuery: const DiscoverExploreQuery(
      category: 'beauty',
      minPriceMinor: null,
      maxPriceMinor: null,
    ),
  );

  DiscoverSection priceBandSection() => DiscoverSection(
    kind: DiscoverSectionKind.priceBand,
    title: 'Gifts Under ₹2000',
    subtitle: null,
    person: null,
    items: [product('p2')],
    exploreQuery: const DiscoverExploreQuery(
      category: null,
      minPriceMinor: null,
      maxPriceMinor: 200000,
    ),
  );

  DiscoverSection premiumSection() => DiscoverSection(
    kind: DiscoverSectionKind.premium,
    title: 'Premium Picks for You',
    subtitle: null,
    person: null,
    items: [product('p3')],
    exploreQuery: const DiscoverExploreQuery(
      category: null,
      minPriceMinor: 500000,
      maxPriceMinor: null,
    ),
  );

  Future<void> pump(WidgetTester tester, List<DiscoverSection> sections) async {
    // A phone-sized surface, not the 800×600 default — at 600 tall, a second
    // stacked shelf can land below the fold, and a ListView only builds the
    // elements a viewport this size actually reaches.
    tester.view
      ..physicalSize = const Size(393, 1200)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeDiscoverRepository(
      feedResult: DiscoverFeed(sections: sections),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [discoverRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: DiscoverBody()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  TextStyle? styleOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style;

  testWidgets('a person shelf heading is upright, not italic', (tester) async {
    await pump(tester, [personSection()]);

    final style = styleOf(tester, "Gift suggestions for Siya's Birthday");
    expect(style?.fontStyle, isNot(FontStyle.italic));
  });

  testWidgets('the price-band heading is italic — the one heading on this '
      'screen that is', (tester) async {
    await pump(tester, [priceBandSection()]);

    final style = styleOf(tester, 'Gifts Under ₹2000');
    expect(style?.fontStyle, FontStyle.italic);
  });

  testWidgets('the premium heading gets a client-side 🔥, not carried in '
      "the server's own title", (tester) async {
    await pump(tester, [premiumSection()]);

    expect(find.text('Premium Picks for You 🔥'), findsOneWidget);
    expect(find.text('Premium Picks for You'), findsNothing);
  });

  testWidgets('the price-band shelf sits on a full-bleed white section, '
      'unlike the others', (tester) async {
    await pump(tester, [priceBandSection()]);

    // Narrowed to the section's own fill colour — a plain `find.byType`
    // also catches `WishtickImage`'s placeholder, which is a `ColoredBox`
    // too (the fixture products here have no image URL).
    final sectionFill = find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == WishtickColors.light.surface,
    );
    expect(sectionFill, findsOneWidget);
  });

  testWidgets('a person section and a grid section can render side by side', (
    tester,
  ) async {
    await pump(tester, [personSection(), premiumSection()]);

    expect(find.text('Siya'), findsOneWidget);
    expect(find.text('Premium Picks for You 🔥'), findsOneWidget);
  });
}
