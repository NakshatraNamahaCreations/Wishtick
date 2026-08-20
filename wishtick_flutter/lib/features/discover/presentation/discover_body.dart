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
import 'widgets/discover_grid_shelf.dart';
import 'widgets/discover_person_shelf.dart';

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

    // No horizontal padding here — the price-band shelf below breaks out to a
    // full-bleed white section (`280:131`), so every *other* child carries
    // its own horizontal inset instead of the list imposing one uniformly.
    return RefreshIndicator(
      onRefresh: () => ref.read(discoverProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchField(onTap: () => unawaited(_openSearch())),
                const SizedBox(height: AppSpacing.lg),
                const _CuratedBanner(),
              ],
            ),
          ),
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
            for (final section in feed.sections)
              _SectionGap(
                kind: section.kind,
                child: _Section(
                  section: section,
                  onExplore: () => unawaited(_openShelf(section)),
                  onProductTap: (p) => unawaited(_openProduct(p)),
                ),
              ),
        ],
      ),
    );
  }
}

/// Top margin above a shelf.
///
/// A plain [SizedBox] everywhere except above the price-band shelf: that one
/// is a full-bleed white section (`280:131`), so its own gap has to be
/// *inside* the white fill rather than beige page showing through above it.
class _SectionGap extends StatelessWidget {
  const _SectionGap({required this.kind, required this.child});

  final DiscoverSectionKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kind == DiscoverSectionKind.priceBand) {
      return Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          child,
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: child,
    );
  }
}

/// One shelf, dispatched by [DiscoverSectionKind].
class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.onExplore,
    required this.onProductTap,
  });

  final DiscoverSection section;
  final VoidCallback onExplore;
  final ValueChanged<NormalizedProduct> onProductTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final person = section.person;

    final heading = Text(
      // The 🔥 is a client-side flourish, not part of the server's title —
      // it is not text that would survive translation or a copy change.
      section.kind == DiscoverSectionKind.premium
          ? '${section.title} 🔥'
          : section.title,
      style: context.text.titleMedium?.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
        // Sampled off the export: "Gifts Under ₹2000" alone is italic, unlike
        // every other Discover heading.
        fontStyle: section.kind == DiscoverSectionKind.priceBand
            ? FontStyle.italic
            : FontStyle.normal,
      ),
    );

    final body = person != null
        ? DiscoverPersonShelf(
            person: person,
            items: section.items,
            onExplore: onExplore,
            onProductTap: onProductTap,
          )
        : DiscoverGridShelf(
            items: section.items,
            onProductTap: onProductTap,
            onSave: onProductTap,
            onExplore: onExplore,
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        const SizedBox(height: AppSpacing.md),
        body,
      ],
    );

    if (section.kind != DiscoverSectionKind.priceBand) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: content,
      );
    }

    // Full-bleed white, breaking past the page's own horizontal margin —
    // the one section on this screen that is not on the beige page colour.
    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: content,
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

  /// Tall enough to clear the gift-box photo even when the text column's own
  /// content would otherwise be shorter (the photo is [Positioned], so it
  /// does not contribute to the [Stack]'s intrinsic height on its own).
  static const _minHeight = 124.0;

  /// Reserves room so the text column never runs under the photo.
  static const _imageReserve = 110.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ClipRRect(
      // Sampled off the export: a modest ~8px radius, not the pill/lg radius
      // used elsewhere for large cards.
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: _minHeight),
        decoration: BoxDecoration(gradient: context.gradients.curatedBanner),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                _imageReserve,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      style: context.text.titleMedium?.copyWith(
                        color: colors.textOnDark,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      children: const [
                        TextSpan(text: 'CURATED GIFTS\nFOR EVERY '),
                        // Sampled off the export: "OCCASION" alone is italic.
                        TextSpan(
                          text: 'OCCASION',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
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
            ),
            Positioned(
              right: AppSpacing.md,
              bottom: 0,
              child: Image.asset(
                'assets/images/gift_box.png',
                width: 95,
                height: 102,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
