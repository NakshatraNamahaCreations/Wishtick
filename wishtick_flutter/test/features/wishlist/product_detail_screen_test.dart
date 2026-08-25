import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishlist/data/product_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/product.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/product_detail_screen.dart';

import '../../helpers/wishlist_fakes.dart';

/// The detail screen shows everything the catalogue actually gives us.
///
/// All of it is sparse — Google Shopping publishes a rating on a small
/// minority of rows and an MRP on fewer still — so the absent case is the
/// common one and is tested as carefully as the present one.
void main() {
  NormalizedProduct product({
    String? merchant = 'amazon.in',
    int? amountMinor = 69900,
    int? listPriceMinor,
    double? rating,
    int? reviewCount,
    String? deliveryNote,
  }) => NormalizedProduct(
    provider: 'serpapi',
    externalId: 'p1',
    title: 'Copper Metal Plant Pot',
    description: null,
    imageUrls: const [],
    productUrl: 'https://example.test/p1',
    affiliateUrl: null,
    amountMinor: amountMinor,
    listPriceMinor: listPriceMinor,
    currency: 'INR',
    merchant: merchant,
    category: null,
    inStock: true,
    rating: rating,
    reviewCount: reviewCount,
    deliveryNote: deliveryNote,
  );

  late FakeProductRepository products;

  setUp(() => products = FakeProductRepository());

  Future<void> pump(WidgetTester tester, NormalizedProduct p) async {
    tester.view
      ..physicalSize = const Size(393, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [productRepositoryProvider.overrideWithValue(products)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: ProductDetailScreen.fromSearch(p),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the seller the catalogue named', (tester) async {
    await pump(tester, product());

    expect(find.text('amazon.in'), findsOneWidget);
  });

  testWidgets('shows the rating and how many reviews it averages', (
    tester,
  ) async {
    await pump(tester, product(rating: 4.3, reviewCount: 128));

    // One decimal always, so 4.0 and 4.3 read as the same kind of number.
    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('(128)'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('a big review count groups like every other number on the '
      'screen', (tester) async {
    await pump(tester, product(rating: 4.5, reviewCount: 13000));

    expect(find.text('(13,000)'), findsOneWidget);
  });

  testWidgets('a whole-number rating still reads as a score, not a count', (
    tester,
  ) async {
    await pump(tester, product(rating: 4));

    expect(find.text('4.0'), findsOneWidget);
    // No review count published — the parenthetical is dropped rather than
    // showing "(0)", which would read as "nobody rated this".
    expect(find.text('(0)'), findsNothing);
  });

  testWidgets('no rating means no star at all, never an empty row', (
    tester,
  ) async {
    await pump(tester, product());

    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('quotes the delivery promise when the provider made one', (
    tester,
  ) async {
    await pump(tester, product(deliveryNote: 'Free delivery by Tue, 26 Aug'));

    expect(find.text('Free delivery by Tue, 26 Aug'), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
  });

  testWidgets('no delivery line when the provider gave none', (tester) async {
    await pump(tester, product());

    expect(find.byIcon(Icons.local_shipping_outlined), findsNothing);
  });

  testWidgets('strikes through a genuinely higher MRP', (tester) async {
    await pump(tester, product(amountMinor: 139900, listPriceMinor: 168700));

    expect(find.text('₹1,399'), findsOneWidget);
    expect(find.text('₹1,687'), findsOneWidget);
  });

  testWidgets('an MRP equal to the price invents no saving', (tester) async {
    await pump(tester, product(amountMinor: 69900, listPriceMinor: 69900));

    // The price itself renders once; the MRP must not appear beside it.
    expect(find.text('₹699'), findsOneWidget);
  });

  group('enrichment', () {
    NormalizedProduct enriched({
      List<ProductFeature> features = const [],
      List<ProductOffer> offers = const [],
      List<String> imageUrls = const [],
      String? brand,
    }) => NormalizedProduct(
      provider: 'serpapi',
      externalId: 'p1',
      title: 'Copper Metal Plant Pot',
      description: null,
      imageUrls: imageUrls,
      productUrl: 'https://example.test/p1',
      affiliateUrl: null,
      amountMinor: 69900,
      listPriceMinor: null,
      currency: 'INR',
      merchant: 'amazon.in',
      category: null,
      inStock: true,
      brand: brand,
      features: features,
      offers: offers,
    );

    testWidgets('the page renders from the search result before the lookup '
        'lands — it never blocks on it', (tester) async {
      products.detailsResult = enriched(
        features: const [ProductFeature(label: 'Form', value: 'Over-ear')],
      );
      await pump(tester, product());

      // Title is up on the very first frame, with the lookup still in flight.
      expect(find.text('Copper Metal Plant Pot'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Over-ear'), findsOneWidget);
    });

    testWidgets('fills in the spec table once the lookup returns', (
      tester,
    ) async {
      products.detailsResult = enriched(
        brand: 'Zebronics',
        features: const [
          ProductFeature(label: 'Noise Cancelling', value: 'Yes'),
          ProductFeature(label: 'Form', value: 'Over-ear'),
        ],
      );
      await pump(tester, product());
      await tester.pumpAndSettle();

      expect(find.text('About this Zebronics'), findsOneWidget);
      expect(find.text('Noise Cancelling'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(products.detailsCalls, ['serpapi/p1']);
    });

    testWidgets('lists every seller, flagging the cheapest', (tester) async {
      products.detailsResult = enriched(
        offers: const [
          ProductOffer(
            merchant: 'Amazon.in',
            amountMinor: 69900,
            url: 'https://a.test',
          ),
          ProductOffer(
            merchant: 'Flipkart',
            amountMinor: 99900,
            url: 'https://f.test',
          ),
        ],
      );
      await pump(tester, product());
      await tester.pumpAndSettle();

      expect(find.text('Available at 2 sellers'), findsOneWidget);
      expect(find.text('Amazon.in'), findsWidgets);
      expect(find.text('Flipkart'), findsOneWidget);
      // Exactly one — the badge marks the cheapest, not every row.
      expect(find.text('Best price'), findsOneWidget);
    });

    testWidgets('a single seller is not a comparison worth showing', (
      tester,
    ) async {
      products.detailsResult = enriched(
        offers: const [
          ProductOffer(
            merchant: 'Amazon.in',
            amountMinor: 69900,
            url: 'https://a.test',
          ),
        ],
      );
      await pump(tester, product());
      await tester.pumpAndSettle();

      expect(find.textContaining('Available at'), findsNothing);
    });

    testWidgets('a failed lookup is silent — the page was never incomplete', (
      tester,
    ) async {
      products.detailsFailure = const ApiException(
        code: ApiException.codeNetwork,
        message: 'down',
      );
      await pump(tester, product(deliveryNote: 'Free delivery'));
      await tester.pumpAndSettle();

      // Everything the search gave is still there, and no error is shown.
      expect(find.text('Copper Metal Plant Pot'), findsOneWidget);
      expect(find.text('Free delivery'), findsOneWidget);
      expect(find.textContaining('down'), findsNothing);
    });

    testWidgets('a scraped URL has no provider identity, so nothing is '
        'looked up', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [productRepositoryProvider.overrideWithValue(products)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: ProductDetailScreen.fromResolved(
              const ResolvedUrlProduct(
                fromKnownProvider: false,
                title: 'Pasted thing',
                productUrl: 'https://shop.test/x',
                description: null,
                imageUrls: [],
                amountMinor: 1000,
                currency: 'INR',
                provider: null,
                externalId: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(products.detailsCalls, isEmpty);
    });
  });
}
