import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/currency.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../data/wishlist_repository.dart';
import '../domain/public_wishlist.dart';
import 'widgets/merchant_label.dart';

/// Which items the tab bar is showing.
enum _ItemFilter {
  all('All'),
  available('Available'),
  claimed('Reserved');

  const _ItemFilter(this.label);

  final String label;
}

/// Figma `291:1074` — a wishlist opened through its share link.
///
/// The mock's tabs read All / Available / Reserved / Purchased. The public
/// view deliberately reports only `isClaimed`, never the granular status, so
/// Reserved and Purchased cannot be told apart here — they are shown as one
/// "Reserved" tab rather than as two tabs that would be guessing.
class PublicWishlistScreen extends ConsumerStatefulWidget {
  const PublicWishlistScreen({required this.slug, this.passcode, super.key});

  final String slug;
  final String? passcode;

  @override
  ConsumerState<PublicWishlistScreen> createState() =>
      _PublicWishlistScreenState();
}

class _PublicWishlistScreenState extends ConsumerState<PublicWishlistScreen> {
  PublicWishlist? _wishlist;
  String? _error;
  bool _loading = true;
  _ItemFilter _filter = _ItemFilter.all;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wishlist = await ref
          .read(wishlistRepositoryProvider)
          .publicBySlug(widget.slug, passcode: widget.passcode);
      if (!mounted) return;
      setState(() {
        _wishlist = wishlist;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<PublicWishlistItem> _visible(
    PublicWishlist wishlist,
  ) => switch (_filter) {
    _ItemFilter.all => wishlist.items,
    _ItemFilter.available => wishlist.items.where((i) => !i.isClaimed).toList(),
    _ItemFilter.claimed => wishlist.items.where((i) => i.isClaimed).toList(),
  };

  int _countFor(PublicWishlist wishlist, _ItemFilter filter) =>
      switch (filter) {
        _ItemFilter.all => wishlist.items.length,
        _ItemFilter.available => wishlist.availableCount,
        _ItemFilter.claimed => wishlist.claimedCount,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final wishlist = _wishlist;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: switch ((wishlist, _loading, _error)) {
          (_, true, _) => const Center(child: CircularProgressIndicator()),
          (_, _, final String message) => Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WishtickErrorText(message),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => unawaited(_load()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          (final PublicWishlist loaded, _, _) => _Body(
            wishlist: loaded,
            filter: _filter,
            visible: _visible(loaded),
            countFor: (f) => _countFor(loaded, f),
            onFilterChanged: (f) => setState(() => _filter = f),
          ),
          _ => Center(
            child: Text(
              'That link is no longer available.',
              style: context.text.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.wishlist,
    required this.filter,
    required this.visible,
    required this.countFor,
    required this.onFilterChanged,
  });

  final PublicWishlist wishlist;
  final _ItemFilter filter;
  final List<PublicWishlistItem> visible;
  final int Function(_ItemFilter) countFor;
  final ValueChanged<_ItemFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final owner = wishlist.ownerFirstName;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owner == null ? wishlist.title : "$owner's ${wishlist.title}",
                  style: context.text.headlineMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${wishlist.itemCount} items',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (wishlist.description != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    wishlist.description!,
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _ItemFilter.values) ...[
                        _FilterTab(
                          label: '${f.label} (${countFor(f)})',
                          selected: f == filter,
                          onTap: () => onFilterChanged(f),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Text(
                  'Nothing here yet.',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _PublicItemCard(item: visible[index]),
                childCount: visible.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.text.titleSmall?.copyWith(
              color: selected ? colors.primary : colors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(height: 2, width: selected ? 40 : 0, color: colors.primary),
        ],
      ),
    );
  }
}

class _PublicItemCard extends StatelessWidget {
  const _PublicItemCard({required this.item});

  final PublicWishlistItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final merchant = merchantLabel(item.productLink);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: WishtickImage(
                      url: item.coverImageUrl,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  if (item.isClaimed)
                    Positioned(
                      left: AppSpacing.xs,
                      top: AppSpacing.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryDeep,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'Reserved',
                          style: context.text.labelSmall?.copyWith(
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              formatInrMinor(item.price.amountMinor),
              style: AppTypography.price.copyWith(color: colors.textPrimary),
            ),
            if (merchant != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                merchant,
                style: context.text.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
