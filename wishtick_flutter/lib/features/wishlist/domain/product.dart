import 'package:flutter/foundation.dart';

/// How fresh a search/lookup result is — the backend serves cached or stale
/// results rather than failing outright when the upstream provider is slow.
enum ResultFreshness {
  live('live'),
  cached('cached'),
  stale('stale');

  const ResultFreshness(this.wireValue);

  final String wireValue;

  static ResultFreshness fromWire(String? value) => ResultFreshness.values
      .firstWhere((v) => v.wireValue == value, orElse: () => live);
}

/// One product from search, a provider lookup, or (partially) a resolved URL
/// (`NormalizedProduct`). Identity is `(provider, externalId)`.
@immutable
class NormalizedProduct {
  const NormalizedProduct({
    required this.provider,
    required this.externalId,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.productUrl,
    required this.affiliateUrl,
    required this.amountMinor,
    required this.listPriceMinor,
    required this.currency,
    required this.merchant,
    required this.category,
    required this.inStock,
  });

  final String provider;
  final String externalId;
  final String title;
  final String? description;
  final List<String> imageUrls;
  final String productUrl;
  final String? affiliateUrl;
  final int? amountMinor;

  /// The pre-discount / MRP price. Null means there is no saving to show, so
  /// the card renders a plain price rather than a struck-through fake one.
  final int? listPriceMinor;

  final String currency;
  final String? merchant;
  final String? category;
  final bool inStock;

  double? get amount => amountMinor == null ? null : amountMinor! / 100;
  String? get coverImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  /// Only true when the backend gave a genuinely higher list price.
  bool get isDiscounted =>
      listPriceMinor != null &&
      amountMinor != null &&
      listPriceMinor! > amountMinor!;

  factory NormalizedProduct.fromJson(Map<String, dynamic> json) =>
      NormalizedProduct(
        provider: json['provider'] as String? ?? '',
        externalId: json['externalId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        imageUrls: (json['imageUrls'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        productUrl: json['productUrl'] as String? ?? '',
        affiliateUrl: json['affiliateUrl'] as String?,
        amountMinor: json['amountMinor'] as int?,
        listPriceMinor: json['listPriceMinor'] as int?,
        currency: json['currency'] as String? ?? 'INR',
        merchant: json['merchant'] as String?,
        category: json['category'] as String?,
        inStock: json['inStock'] as bool? ?? true,
      );
}

/// A page of `GET /products/search`.
@immutable
class ProductSearchResult {
  const ProductSearchResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalEstimate,
    required this.hasMore,
    required this.freshness,
  });

  final List<NormalizedProduct> items;
  final int page;
  final int pageSize;

  /// Null means "unknown", not zero.
  final int? totalEstimate;
  final bool hasMore;
  final ResultFreshness freshness;

  factory ProductSearchResult.fromJson(Map<String, dynamic> json) =>
      ProductSearchResult(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => NormalizedProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 20,
        totalEstimate: json['totalEstimate'] as int?,
        hasMore: json['hasMore'] as bool? ?? false,
        freshness: ResultFreshness.fromWire(json['freshness'] as String?),
      );
}

/// The result of `POST /products/resolve-url` — a pasted product link,
/// resolved either by a recognised affiliate network or by scraping the page.
@immutable
class ResolvedUrlProduct {
  const ResolvedUrlProduct({
    required this.fromKnownProvider,
    required this.title,
    required this.productUrl,
    required this.description,
    required this.imageUrls,
    required this.amountMinor,
    required this.currency,
    required this.provider,
    required this.externalId,
  });

  /// `true` when a recognised affiliate network answered directly (`source:
  /// 'provider'`); `false` when the page was scraped for Open Graph tags
  /// (`source: 'scrape'`) — scraped results have no `affiliateUrl`/provider
  /// identity, only what the page happened to publish.
  final bool fromKnownProvider;

  final String title;
  final String productUrl;
  final String? description;
  final List<String> imageUrls;
  final int? amountMinor;
  final String currency;

  /// Present only when [fromKnownProvider] is true — needed to import via
  /// `POST /wishlists/:id/items/from-product`.
  final String? provider;
  final String? externalId;

  double? get amount => amountMinor == null ? null : amountMinor! / 100;
  String? get coverImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  factory ResolvedUrlProduct.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>? ?? const {};
    return ResolvedUrlProduct(
      fromKnownProvider: json['source'] == 'provider',
      title: product['title'] as String? ?? '',
      productUrl: product['productUrl'] as String? ?? '',
      description: product['description'] as String?,
      imageUrls: (product['imageUrls'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      amountMinor: product['amountMinor'] as int?,
      currency: product['currency'] as String? ?? 'INR',
      provider: product['provider'] as String?,
      externalId: product['externalId'] as String?,
    );
  }
}
