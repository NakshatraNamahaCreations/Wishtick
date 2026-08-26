import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// `LinkDelegate` is not re-exported by the package's main entrypoint.
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:wishtick_flutter/core/network/api_client.dart';
import 'package:wishtick_flutter/core/network/api_config.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/gifting/data/gifting_repository.dart';
import 'package:wishtick_flutter/features/wishlist/data/product_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/product.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/product_detail_screen.dart';

import '../../helpers/wishlist_fakes.dart';

/// Where the buy buttons actually send people.
///
/// This is the revenue path, and every way it breaks is silent: an inert row,
/// or one that opens the merchant directly, both look completely normal on
/// screen and simply earn nothing. Nothing here checks pixels.
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

  /// Only used by the `Link` widget, which this app does not render.
  @override
  LinkDelegate? get linkDelegate => null;
}

void main() {
  late _RecordingLauncher launcher;
  late FakeProductRepository products;

  setUp(() {
    launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
    products = FakeProductRepository();
  });

  NormalizedProduct product({List<ProductOffer> offers = const []}) =>
      NormalizedProduct(
        provider: 'serpapi',
        externalId: 'B0XYZ',
        title: 'Saregama Carvaan Mini',
        description: null,
        imageUrls: const [],
        productUrl: 'https://google.test/shopping/B0XYZ',
        affiliateUrl: null,
        amountMinor: 249000,
        listPriceMinor: null,
        currency: 'INR',
        merchant: 'Amazon.in',
        category: null,
        inStock: true,
        rating: null,
        reviewCount: null,
        deliveryNote: null,
        offers: offers,
      );

  const threeSellers = [
    ProductOffer(
      merchant: 'Amazon.in',
      amountMinor: 249000,
      url: 'https://amazon.test/p/1',
    ),
    ProductOffer(
      merchant: 'Nykaa Fashion',
      amountMinor: 249100,
      url: 'https://nykaa.test/p/1',
    ),
    ProductOffer(
      merchant: 'Vijay Sales',
      amountMinor: 299000,
      url: 'https://vijay.test/p/1',
    ),
  ];

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

  group('the redirect URL', () {
    // The builders are pure string work; the client is never called.
    final repo = GiftingRepository(ApiClient(Dio()));

    test('names the seller by index so each one converts its own link', () {
      expect(
        repo.productRedirectUri('serpapi', 'B0XYZ', offerIndex: 2).toString(),
        '${ApiConfig.baseUrl}/r/p/serpapi/B0XYZ?offer=2',
      );
    });

    test('index 0 is sent, not dropped — it is a real seller, not "none"', () {
      // `if (offerIndex != null)` is easy to write as a truthiness check, and
      // 0 is the *best price* row, so that bug would misroute the likeliest
      // click of all.
      expect(
        repo.productRedirectUri('serpapi', 'B0XYZ', offerIndex: 0).toString(),
        endsWith('?offer=0'),
      );
    });

    test('no index means the product itself', () {
      expect(
        repo.productRedirectUri('serpapi', 'B0XYZ').toString(),
        '${ApiConfig.baseUrl}/r/p/serpapi/B0XYZ',
      );
    });
  });

  testWidgets('a seller row opens our redirect, never the merchant directly', (
    tester,
  ) async {
    await pump(tester, product(offers: threeSellers));

    await tester.tap(find.text('Vijay Sales'));
    await tester.pumpAndSettle();

    expect(launcher.opened, hasLength(1));
    // The whole point of the row: going to vijay.test directly would work
    // perfectly and pay us nothing.
    expect(launcher.opened.single, contains('/r/p/serpapi/B0XYZ'));
    expect(launcher.opened.single, contains('offer=2'));
    expect(launcher.opened.single, isNot(contains('vijay.test')));
  });

  testWidgets('each row carries its own index, not the first one', (
    tester,
  ) async {
    await pump(tester, product(offers: threeSellers));

    await tester.tap(find.text('Nykaa Fashion'));
    await tester.pumpAndSettle();

    expect(launcher.opened.single, contains('offer=1'));
  });
}
