import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/product.dart';

/// Talks to the backend's `products` module — search and pasted-URL resolve.
///
/// Importing a resolved/searched product onto a wishlist is
/// `POST /wishlists/:id/items/from-product`, which lives on
/// [WishlistRepository] instead — it operates on a wishlist's items, matching
/// how every other item endpoint is grouped. That endpoint only knows a
/// catalogue product's `(provider, externalId)`; a scraped (non-catalogue)
/// resolved product has neither, so it goes through the plain
/// [WishlistRepository.addItem] with its fields copied across instead.
class ProductRepository {
  ProductRepository(this._api);

  final ApiClient _api;

  Future<ProductSearchResult> search({
    String? query,
    String? category,
    int? minPriceMinor,
    int? maxPriceMinor,
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/products/search',
      query: {
        'q': ?query,
        'category': ?category,
        'minPriceMinor': ?minPriceMinor,
        'maxPriceMinor': ?maxPriceMinor,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return ProductSearchResult.fromJson(json);
  }

  /// One product in full — specs, every seller, and the whole image gallery.
  ///
  /// Costs the backend a second upstream call, so this is only worth asking
  /// for once someone has actually opened a product. A search result is
  /// already enough to render the page; this fills in what it could not carry.
  Future<NormalizedProduct> details({
    required String provider,
    required String externalId,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/products/$provider/$externalId',
    );
    return NormalizedProduct.fromJson(json['product'] as Map<String, dynamic>);
  }

  /// Resolves a pasted product URL — either a recognised affiliate network
  /// answers directly, or the page is scraped for Open Graph tags.
  Future<ResolvedUrlProduct> resolveUrl(String url) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/products/resolve-url',
      body: {'url': url},
    );
    return ResolvedUrlProduct.fromJson(json);
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(apiClientProvider));
});
