import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../wishlist/domain/product.dart';
import '../../wishlist/presentation/product_detail_screen.dart';
import '../domain/discover_feed.dart';
import 'discover_controller.dart';
import 'explore_products_screen.dart';
import 'widgets/discover_product_card.dart';

/// Figma `280:131` — the Discover segment of the wishlist tab.
///
/// A body rather than a screen: it renders inside the tab shell that
/// `WishlistTabScreen` already owns, alongside "My Wishlist".
class DiscoverBody extends ConsumerStatefulWidget {
  const DiscoverBody({super.key});

  @override
  ConsumerState<DiscoverBody> createState() => _DiscoverBodyState();
}

class _DiscoverBodyState extends ConsumerState<DiscoverBody> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(discoverProvider.notifier).ensureLoaded());
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const ExploreProductsScreen.search(),
      ),
    );
  }

  Future<void> _openShelf(DiscoverSection section) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ExploreProductsScreen.forShelf(
          title: section.title,
          query: section.exploreQuery,
        ),
      ),
    );
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
    final state = ref.watch(discoverProvider);
    final colors = context.colors;
    final feed = state.feed;

    if (feed == null) {
      return state.error == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WishtickErrorText(state.error!),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () =>
                        ref.read(discoverProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(discoverProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.huge,
        ),
        children: [
          _SearchField(onTap: () => unawaited(_openSearch())),
          const SizedBox(height: AppSpacing.lg),
          const _CuratedBanner(),
          const SizedBox(height: AppSpacing.xl),
          if (feed.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.huge),
              child: Center(
                child: Text(
                  'Nothing to suggest just yet.',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            )
          else
            for (final section in feed.sections) ...[
              _Shelf(
                section: section,
                onExplore: () => unawaited(_openShelf(section)),
                onProductTap: (p) => unawaited(_openProduct(p)),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: AppSizes.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: colors.textMuted, size: AppSizes.iconMd),
            const SizedBox(width: AppSpacing.sm),
            // Flexible so a longer (or localized) hint ellipsizes instead of
            // overflowing the field.
            Flexible(
              child: Text(
                'What are you looking for?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CuratedBanner extends StatelessWidget {
  const _CuratedBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: context.gradients.celebration,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURATED GIFTS\nFOR EVERY OCCASION',
            style: context.text.titleMedium?.copyWith(
              color: colors.textOnDark,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "From birthdays to milestones, we've got you covered",
            style: context.text.bodySmall?.copyWith(
              color: colors.textOnDark.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// One shelf: a heading, a horizontal run of products, and "Explore More".
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.section,
    required this.onExplore,
    required this.onProductTap,
  });

  final DiscoverSection section;
  final VoidCallback onExplore;
  final ValueChanged<NormalizedProduct> onProductTap;

  static const _cardWidth = 150.0;
  static const _railHeight = 290.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (section.subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            section.subtitle!,
            style: context.text.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: _railHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final product = section.items[index];
              return SizedBox(
                width: _cardWidth,
                child: DiscoverProductCard(
                  product: product,
                  onTap: () => onProductTap(product),
                  onSave: () => onProductTap(product),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onExplore,
            child: const Text('Explore More'),
          ),
        ),
      ],
    );
  }
}
