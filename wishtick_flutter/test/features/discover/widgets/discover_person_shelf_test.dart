import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/discover/domain/discover_feed.dart';
import 'package:wishtick_flutter/features/discover/presentation/widgets/discover_person_shelf.dart';
import 'package:wishtick_flutter/features/wishlist/domain/product.dart';

void main() {
  NormalizedProduct product(
    String id, {
    String title = 'Dior Rouge Lipstick',
  }) => NormalizedProduct(
    provider: 'fixture',
    externalId: id,
    title: title,
    description: null,
    imageUrls: const [],
    productUrl: 'https://example.test/$id',
    affiliateUrl: null,
    amountMinor: 470000,
    listPriceMinor: 690000,
    currency: 'INR',
    merchant: 'Amazon',
    category: null,
    inStock: true,
  );

  final person = DiscoverPerson(
    importantDateId: 'd1',
    name: 'Siya',
    relation: 'Best Friend',
    occasionKey: 'birthday',
    occasionLabel: 'Birthday',
    nextOccurrence: DateTime(2026, 7, 26),
    daysAway: 3,
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<NormalizedProduct> items,
    VoidCallback? onExplore,
    ValueChanged<NormalizedProduct>? onProductTap,
  }) async {
    // A phone-sized surface, not the 800×600 default — at 800 wide the
    // three-tile row runs too tall for the default 600-tall test window.
    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DiscoverPersonShelf(
            person: person,
            items: items,
            onExplore: onExplore ?? () {},
            onProductTap: onProductTap ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows the person, their relation and the next date', (
    tester,
  ) async {
    await pump(tester, items: [product('p1')]);

    expect(find.text('Siya'), findsOneWidget);
    expect(find.text('Best Friend'), findsOneWidget);
    expect(find.text('26 July'), findsOneWidget);
  });

  testWidgets('shows up to three product tiles, one per item given', (
    tester,
  ) async {
    await pump(
      tester,
      items: [product('p1'), product('p2'), product('p3'), product('p4')],
    );

    // Capped at three even though four were handed in — the card only has
    // room for three, and the export never shows a fourth.
    expect(find.text('Dior Rouge Lipstick'), findsNWidgets(3));
  });

  testWidgets('renders fewer tiles when fewer items are given, without '
      'padding the row out', (tester) async {
    await pump(tester, items: [product('p1')]);

    expect(find.text('Dior Rouge Lipstick'), findsOneWidget);
  });

  testWidgets('a tile has no save button and no brand badge — bare content '
      'only', (tester) async {
    await pump(tester, items: [product('p1')]);

    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.text('Amazon'), findsNothing);
  });

  testWidgets('tapping a tile reports that product', (tester) async {
    NormalizedProduct? tapped;
    final target = product('p1');
    await pump(tester, items: [target], onProductTap: (p) => tapped = p);

    await tester.tap(find.text('Dior Rouge Lipstick'));
    await tester.pump();

    expect(tapped, target);
  });

  testWidgets('tapping Explore More calls onExplore', (tester) async {
    var explored = false;
    await pump(
      tester,
      items: [product('p1')],
      onExplore: () => explored = true,
    );

    await tester.tap(find.text('Explore More'));
    await tester.pump();

    expect(explored, isTrue);
  });
}
