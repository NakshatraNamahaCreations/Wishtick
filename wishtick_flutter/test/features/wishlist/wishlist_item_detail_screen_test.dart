import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishlist/data/product_repository.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/product.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/occasion_labels_provider.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/widgets/catalogue_detail_sections.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/wishlist_item_detail_screen.dart';

import '../../helpers/wishlist_fakes.dart';
import '../../helpers/wishmates_fakes.dart' show fakeApiFailure;

/// "Product Details" for an item already on a wishlist (`280:300`).
///
/// The item stores a snapshot — title, price, one image — frozen at import.
/// Everything richer belongs to the catalogue row it came from and has to be
/// fetched, which is what these cover: that it *is* fetched, that the page is
/// complete before it lands, and that the snapshot is never overwritten by it.
/// Records where a tap sends the user, without leaving the test.
class _RecordingLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final opened = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return true;
  }

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  LinkDelegate? get linkDelegate => null;
}

void main() {
  late FakeWishlistRepository wishlists;
  late FakeProductRepository products;
  late _RecordingLauncher launcher;

  const productId = 'prod_abc';

  NormalizedProduct catalogueRow({
    List<ProductOffer> offers = const [],
    List<ProductFeature> features = const [],
    List<String> imageUrls = const [],
    String? merchant = 'Amazon.in',
    double? rating = 4.0,
    int? reviewCount = 165,
    String? deliveryNote = 'Free delivery',
    int? listPriceMinor,
  }) => NormalizedProduct(
    provider: 'serpapi',
    externalId: 'B0XYZ',
    title: 'Saregama Carvaan Mini',
    description: null,
    imageUrls: imageUrls,
    productUrl: 'https://shop.test/p',
    affiliateUrl: null,
    amountMinor: 249000,
    listPriceMinor: listPriceMinor,
    currency: 'INR',
    merchant: merchant,
    category: null,
    inStock: true,
    rating: rating,
    reviewCount: reviewCount,
    deliveryNote: deliveryNote,
    brand: 'Saregama',
    features: features,
    offers: offers,
  );

  setUp(() {
    launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
    products = FakeProductRepository();
    wishlists = FakeWishlistRepository(
      // Short on purpose: GiftSummaryCard's SummaryRow has no Flexible around
      // its value, so a long wishlist title overflows it. That is a
      // pre-existing limit of a shared widget, not something this screen
      // decides, and it is not what these tests are about.
      wishlists: [buildWishlist(id: 'wl_1', title: 'Birthday')],
      items: [
        buildItem(
          id: 'item_1',
          title: 'Saregama Carvaan Mini',
          sourceProductId: productId,
          imageUrls: const ['https://snapshot.test/1.jpg'],
        ),
      ],
    );
  });

  Future<void> pump(WidgetTester tester) async {
    // Wider than the 393 the design targets, to clear a pre-existing overflow
    // in the shared GiftSummaryCard: its SummaryRow puts the value in a Column
    // after a Spacer() with no Flexible, so "Priority / Medium priority"
    // overflows by 21px at 393 — reproducible with that card alone and nothing
    // else on screen. It is not this screen's to fix (gift_item_screen uses the
    // same widget), and it is not what these tests are about.
    tester.view
      ..physicalSize = const Size(430, 2600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wishlistRepositoryProvider.overrideWithValue(wishlists),
          productRepositoryProvider.overrideWithValue(products),
          // The Gift summary resolves an occasion key to its label through
          // the onboarding taxonomy; unstubbed it reaches the real API client.
          occasionLabelsProvider.overrideWith(
            (ref) async => const {'birthday': 'Birthday'},
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WishlistItemDetailScreen(
            wishlistId: 'wl_1',
            itemId: 'item_1',
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  testWidgets('asks the catalogue for what the saved snapshot never held', (
    tester,
  ) async {
    products.detailsResult = catalogueRow();
    await pump(tester);

    // By the item's own product id — the item has no provider/externalId to
    // look up with, which is the whole reason this path exists.
    expect(products.detailsByIdCalls, [productId]);
  });

  testWidgets('shows the seller and rating, which the item never stored', (
    tester,
  ) async {
    products.detailsResult = catalogueRow();
    await pump(tester);

    expect(find.text('Amazon.in'), findsOneWidget);
    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('(165)'), findsOneWidget);
    expect(find.text('Free delivery'), findsOneWidget);
  });

  testWidgets('lists the other sellers', (tester) async {
    products.detailsResult = catalogueRow(
      offers: const [
        ProductOffer(
          merchant: 'Amazon.in',
          amountMinor: 249000,
          url: 'https://a.test',
        ),
        ProductOffer(
          merchant: 'Vijay Sales',
          amountMinor: 299000,
          url: 'https://v.test',
        ),
      ],
    );
    await pump(tester);

    expect(find.text('Available at 2 sellers'), findsOneWidget);
    expect(find.text('Vijay Sales'), findsOneWidget);
    expect(find.text('Best price'), findsOneWidget);
  });

  testWidgets('shows the specification table under the brand', (tester) async {
    products.detailsResult = catalogueRow(
      features: const [
        ProductFeature(label: 'Bluetooth', value: 'Yes'),
        ProductFeature(label: 'Outdoor', value: 'Yes'),
      ],
    );
    await pump(tester);

    expect(find.text('About this Saregama'), findsOneWidget);
    expect(find.text('Bluetooth'), findsOneWidget);
  });

  testWidgets('the catalogue gallery replaces the single saved image', (
    tester,
  ) async {
    products.detailsResult = catalogueRow(
      imageUrls: const [
        'https://cat.test/1.jpg',
        'https://cat.test/2.jpg',
        'https://cat.test/3.jpg',
      ],
    );
    await pump(tester);

    final gallery = tester.widget<CatalogueGallery>(
      find.byType(CatalogueGallery),
    );
    expect(gallery.imageUrls, hasLength(3));
  });

  testWidgets('the price stays the one that was saved, not the catalogue\'s', (
    tester,
  ) async {
    // The item was saved at ₹10,999; the catalogue now says ₹2,490. Quietly
    // showing today's figure would rewrite what the owner chose.
    products.detailsResult = catalogueRow();
    await pump(tester);

    expect(find.text('₹10,999'), findsOneWidget);
    expect(find.text('₹2,490'), findsNothing);
  });

  testWidgets('an item added by hand asks for nothing and still renders', (
    tester,
  ) async {
    wishlists = FakeWishlistRepository(
      // Short on purpose: GiftSummaryCard's SummaryRow has no Flexible around
      // its value, so a long wishlist title overflows it. That is a
      // pre-existing limit of a shared widget, not something this screen
      // decides, and it is not what these tests are about.
      wishlists: [buildWishlist(id: 'wl_1', title: 'Birthday')],
      // No sourceProductId: typed in by hand, so there is no catalogue row.
      items: [buildItem(id: 'item_1', title: 'Hand-written gift')],
    );
    await pump(tester);

    expect(products.detailsByIdCalls, isEmpty);
    expect(find.text('Hand-written gift'), findsOneWidget);
    expect(find.textContaining('Available at'), findsNothing);
  });

  testWidgets('a failed catalogue lookup leaves the page usable', (
    tester,
  ) async {
    products.detailsFailure = fakeApiFailure;
    await pump(tester);

    // The item was never incomplete, only less detailed — so no error banner,
    // and the buttons still work.
    expect(find.text('Saregama Carvaan Mini'), findsOneWidget);
    expect(find.text('Remove Product'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  group('Gift Now', () {
    testWidgets('goes to the merchant through our affiliate redirect', (
      tester,
    ) async {
      products.detailsResult = catalogueRow();
      await pump(tester);

      await tester.tap(find.text('Gift Now'));
      await tester.pumpAndSettle();

      // The item-scoped redirect, so the click is attributable to the list it
      // was saved on — and never the raw merchant URL, which earns nothing.
      expect(launcher.opened, hasLength(1));
      expect(launcher.opened.single, contains('/r/item_1'));
    });

    testWidgets('says nothing about a later sprint — it works now', (
      tester,
    ) async {
      products.detailsResult = catalogueRow();
      await pump(tester);

      await tester.tap(find.text('Gift Now'));
      await tester.pumpAndSettle();

      expect(find.textContaining('later sprint'), findsNothing);
    });

    testWidgets('a seller row uses the catalogue redirect, not the item one', (
      tester,
    ) async {
      products.detailsResult = catalogueRow(
        offers: const [
          ProductOffer(
            merchant: 'Amazon.in',
            amountMinor: 249000,
            url: 'https://a.test',
          ),
          ProductOffer(
            merchant: 'Vijay Sales',
            amountMinor: 299000,
            url: 'https://v.test',
          ),
        ],
      );
      await pump(tester);

      await tester.tap(find.text('Vijay Sales'));
      await tester.pumpAndSettle();

      // Per seller, so the click converts *that* merchant's link.
      expect(launcher.opened.single, contains('/r/p/serpapi/B0XYZ'));
      expect(launcher.opened.single, contains('offer=1'));
    });
  });
}
