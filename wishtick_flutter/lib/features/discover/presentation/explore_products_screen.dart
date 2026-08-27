import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../wishlist/data/product_repository.dart';
import '../../wishlist/domain/product.dart';
import '../../wishlist/presentation/product_detail_screen.dart';
import '../data/discover_repository.dart';
import '../domain/discover_feed.dart';
import 'widgets/discover_product_card.dart';
import 'widgets/product_card_skeleton.dart';

/// The grid the results and their placeholders share, so the swap from one to
/// the other does not resize or reflow a single cell.
const _kProductGrid = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: AppSpacing.md,
  crossAxisSpacing: AppSpacing.md,
  childAspectRatio: 0.58,
);

const _kGridPadding = EdgeInsets.fromLTRB(
  AppSpacing.lg,
  0,
  AppSpacing.lg,
  AppSpacing.xxl,
);

/// A full-page product grid (Figma `2167:18`).
///
/// Three ways in, all landing on the same grid:
/// * "Explore More" on a Discover shelf — carries that shelf's [exploreQuery];
/// * an occasion tile on Home — resolves its filter from the server so the
///   occasion → category curation is not duplicated here;
/// * Home's search field — starts empty with the keyboard up.
class ExploreProductsScreen extends ConsumerStatefulWidget {
  const ExploreProductsScreen({
    required this.title,
    this.query,
    this.occasionKey,
    this.startInSearch = false,
    super.key,
  });

  /// Pages a Discover shelf using the filter the server handed back.
  const ExploreProductsScreen.forShelf({
    required String title,
    required DiscoverExploreQuery query,
    Key? key,
  }) : this(title: title, query: query, key: key);

  /// Resolves the occasion's filter from `/discover/occasions/:key` first.
  const ExploreProductsScreen.forOccasion({
    required String occasionKey,
    required String title,
    Key? key,
  }) : this(title: title, occasionKey: occasionKey, key: key);

  const ExploreProductsScreen.search({Key? key})
    : this(title: 'Search', startInSearch: true, key: key);

  final String title;
  final DiscoverExploreQuery? query;
  final String? occasionKey;
  final bool startInSearch;

  @override
  ConsumerState<ExploreProductsScreen> createState() =>
      _ExploreProductsScreenState();
}

class _ExploreProductsScreenState extends ConsumerState<ExploreProductsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final _items = <NormalizedProduct>[];
  DiscoverExploreQuery? _filter;
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filter = widget.query;
    _scrollController.addListener(_onScroll);
    Future.microtask(_loadFirstPage);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      unawaited(_loadNextPage());
    }
  }

  /// What to put on screen for a failure.
  ///
  /// The server already writes a sentence for a human — "Product search is
  /// temporarily unavailable. Please try again shortly." — and it is the only
  /// part of the failure a shopper can act on. Interpolating the exception
  /// itself put `ApiException(PRODUCT_SEARCH_UNAVAILABLE, 503):` in front of
  /// it, which reads as a crash and tells them nothing.
  static String _messageFor(Exception e) => switch (e) {
    ApiException(:final code, :final message) => switch (code) {
      ApiException.codeNetwork || ApiException.codeTimeout =>
        'No connection. Check your network and retry.',
      _ => message,
    },
    // Anything not from the API has no message written for a reader, so a
    // generic line is better than whatever `toString` happens to produce.
    _ => 'Something went wrong. Please try again.',
  };

  Future<void> _loadFirstPage() async {
    // An occasion tile knows only its key; the filter behind it is the
    // server's to decide.
    final key = widget.occasionKey;
    if (key != null && _filter == null) {
      try {
        final shelf = await ref
            .read(discoverRepositoryProvider)
            .occasionShelf(key);
        _filter = shelf.exploreQuery;
      } on Exception catch (e) {
        if (!mounted) return;
        setState(() => _error = _messageFor(e));
        return;
      }
    }
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(productRepositoryProvider)
          .search(
            query: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
            category: _filter?.category,
            minPriceMinor: _filter?.minPriceMinor,
            maxPriceMinor: _filter?.maxPriceMinor,
            page: _page,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _page += 1;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageFor(e);
      });
    }
  }

  Future<void> _runSearch() async {
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
    });
    await _loadNextPage();
  }

  Future<void> _openProduct(NormalizedProduct product) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen.fromSearch(product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _searchController,
                autofocus: widget.startInSearch,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => unawaited(_runSearch()),
                decoration: InputDecoration(
                  hintText: 'What are you looking for?',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => unawaited(_runSearch()),
                  ),
                ),
              ),
            ),
            Expanded(
              child: switch ((_items.isEmpty, _loading, _error)) {
                (true, true, _) => const _SkeletonGrid(),
                (true, _, final String message) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      WishtickErrorText(message),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: () => unawaited(_loadNextPage()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                (true, _, _) => Center(
                  child: Text(
                    'Nothing matched that search.',
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                _ => GridView.builder(
                  controller: _scrollController,
                  padding: _kGridPadding,
                  gridDelegate: _kProductGrid,
                  // One extra cell carries the next page's placeholder.
                  itemCount: _items.length + (_loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return const ProductCardSkeleton();
                    }
                    final product = _items[index];
                    return DiscoverProductCard(
                      product: product,
                      onTap: () => unawaited(_openProduct(product)),
                      onSave: () => unawaited(_openProduct(product)),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// What fills the page while the first search is in flight.
///
/// Six cells, which is more than a phone shows at once — the grid should run
/// off the bottom edge the way a full result set does, rather than stopping
/// short and reading as "this is all there is".
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  static const _count = 6;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading products',
      child: GridView.builder(
        // Nothing to reach by scrolling yet, and a bounce over placeholders
        // reads as broken.
        physics: const NeverScrollableScrollPhysics(),
        padding: _kGridPadding,
        gridDelegate: _kProductGrid,
        itemCount: _count,
        itemBuilder: (context, _) => const ProductCardSkeleton(),
      ),
    );
  }
}
