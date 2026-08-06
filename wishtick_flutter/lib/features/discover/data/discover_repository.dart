import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/discover_feed.dart';

/// The Discover feed (`GET /discover/feed`).
///
/// Paging a single shelf is `products/search` with the shelf's own
/// `exploreQuery` — see [DiscoverExploreQuery] — so there is no separate
/// endpoint for "Explore More".
class DiscoverRepository {
  DiscoverRepository(this._api);

  final ApiClient _api;

  Future<DiscoverFeed> feed() async {
    final json = await _api.get<Map<String, dynamic>>('/discover/feed');
    return DiscoverFeed.fromJson(json);
  }

  /// One shelf for an occasion picked from Home's celebration grid. The
  /// occasion → category curation stays server-side, so the client only ever
  /// passes the taxonomy key.
  Future<DiscoverSection> occasionShelf(String occasionKey) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/discover/occasions/$occasionKey',
    );
    return DiscoverSection.fromJson(json);
  }
}

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return DiscoverRepository(ref.watch(apiClientProvider));
});
