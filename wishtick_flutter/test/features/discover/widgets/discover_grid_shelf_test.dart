import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/discover/presentation/widgets/discover_grid_shelf.dart';
import 'package:wishtick_flutter/features/wishlist/domain/product.dart';

void main() {
  NormalizedProduct product(
    String id, {
    String title = 'LED Digital Clock',
    String? merchant = 'Amazon',
  }) => NormalizedProduct(
    provider: 'fixture',
    externalId: id,
    title: title,
    description: null,
    imageUrls: const [],
    productUrl: 'https://example.test/$id',
    affiliateUrl: null,
    amountMinor: 99900,
    listPriceMinor: 149900,
    currency: 'INR',
    merchant: merchant,
    category: null,
    inStock: true,
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<NormalizedProduct> items,
    ValueChanged<NormalizedProduct>? onProductTap,
    ValueChanged<NormalizedProduct>? onSave,
    VoidCallback? onExplore,
  }) async {
    // A phone-sized surface, not the 800×600 default — at 800 wide, two
    // grid columns come out too tall (fixed aspect ratio) to fit the
    // default 600-tall test window.
    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DiscoverGridShelf(
            items: items,
            onProductTap: onProductTap ?? (_) {},
            onSave: onSave ?? (_) {},
            onExplore: onExplore ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('lays the items out two to a row', (tester) async {
    await pump(tester, items: [product('p1'), product('p2')]);

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets('a tile shows its title, price and struck MRP', (tester) async {
    await pump(tester, items: [product('p1')]);

    expect(find.text('LED Digital Clock'), findsOneWidget);
    expect(find.text('₹999'), findsOneWidget);
    expect(find.text('₹1,499'), findsOneWidget);
  });

  testWidgets("Amazon's badge is the wordmark alone — no separate text "
      'label next to it', (tester) async {
    await pump(tester, items: [product('p1', merchant: 'Amazon')]);

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName ==
                'assets/icons/amazon_badge.png',
      ),
      findsOneWidget,
    );
    expect(find.text('Amazon'), findsNothing);
  });

  testWidgets("Myntra's badge pairs its icon with a text label", (
    tester,
  ) async {
    await pump(tester, items: [product('p1', merchant: 'Myntra')]);

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.image as AssetImage).assetName ==
                'assets/icons/myntra_badge.png',
      ),
      findsOneWidget,
    );
    expect(find.text('Myntra'), findsOneWidget);
  });

  testWidgets('an unrecognised merchant falls back to plain text, no logo', (
    tester,
  ) async {
    await pump(tester, items: [product('p1', merchant: 'Nike')]);

    expect(find.text('Nike'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('no merchant renders no badge row at all', (tester) async {
    await pump(tester, items: [product('p1', merchant: null)]);

    expect(find.byType(Image), findsNothing);
    // The save button (a heart icon) must still be there even with no badge.
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('tapping a tile reports that product', (tester) async {
    NormalizedProduct? tapped;
    final target = product('p1');
    await pump(tester, items: [target], onProductTap: (p) => tapped = p);

    await tester.tap(find.text('LED Digital Clock'));
    await tester.pump();

    expect(tapped, target);
  });

  testWidgets('tapping the heart reports that product to onSave, not onTap', (
    tester,
  ) async {
    NormalizedProduct? saved;
    NormalizedProduct? tapped;
    final target = product('p1');
    await pump(
      tester,
      items: [target],
      onSave: (p) => saved = p,
      onProductTap: (p) => tapped = p,
    );

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(saved, target);
    expect(tapped, isNull);
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
