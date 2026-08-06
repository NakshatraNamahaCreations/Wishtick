import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../discover/presentation/discover_body.dart';
import '../domain/wishlist.dart';
import 'widgets/wishlist_card.dart';
import 'wishlists_controller.dart';

enum _TopTab { discover, myWishlist }

enum _VisibilityFilter { all, public, private }

/// The wishlist tab's root — Figma `280:428`, hosting the "Discover"
/// (`280:131`) and "My Wishlist" segments.
class WishlistTabScreen extends ConsumerStatefulWidget {
  const WishlistTabScreen({super.key});

  @override
  ConsumerState<WishlistTabScreen> createState() => _WishlistTabScreenState();
}

class _WishlistTabScreenState extends ConsumerState<WishlistTabScreen> {
  _TopTab _tab = _TopTab.myWishlist;
  _VisibilityFilter _filter = _VisibilityFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(wishlistsProvider.notifier).ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _Header(tab: _tab, onChanged: (tab) => setState(() => _tab = tab)),
            Expanded(
              child: _tab == _TopTab.myWishlist
                  ? _MyWishlistBody(
                      filter: _filter,
                      onFilterChanged: (filter) =>
                          setState(() => _filter = filter),
                    )
                  : const DiscoverBody(),
            ),
          ],
        ),
        if (_tab == _TopTab.myWishlist)
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: _CreateWishlistButton(
              onTap: () => context.push(AppRoutes.wishlistCreate),
            ),
          ),
      ],
    );
  }
}

class _CreateWishlistButton extends StatelessWidget {
  const _CreateWishlistButton({required this.onTap});

  final VoidCallback onTap;

  static const _badgeSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      elevation: 3,
      shadowColor: colors.shadow,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create New Wishlist',
                style: context.text.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: _badgeSize,
                height: _badgeSize,
                decoration: BoxDecoration(
                  color: colors.primaryDeep,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: colors.onPrimary,
                  size: AppSizes.iconSm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tab, required this.onChanged});

  final _TopTab tab;
  final ValueChanged<_TopTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.primaryDeep, colors.shadow],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              _TabLabel(
                label: 'Discover',
                selected: tab == _TopTab.discover,
                onTap: () => onChanged(_TopTab.discover),
              ),
              const SizedBox(width: AppSpacing.xxl),
              _TabLabel(
                label: 'My Wishlist',
                selected: tab == _TopTab.myWishlist,
                onTap: () => onChanged(_TopTab.myWishlist),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
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
    final color = selected
        ? colors.textOnDark
        : colors.textOnDark.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.text.titleMedium?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedContainer(
            duration: AppDurations.fast,
            height: 2,
            width: selected ? 28 : 0,
            color: colors.textOnDark,
          ),
        ],
      ),
    );
  }
}

class _MyWishlistBody extends ConsumerWidget {
  const _MyWishlistBody({required this.filter, required this.onFilterChanged});

  final _VisibilityFilter filter;
  final ValueChanged<_VisibilityFilter> onFilterChanged;

  static bool _matches(Wishlist w, _VisibilityFilter f) => switch (f) {
    _VisibilityFilter.all => true,
    _VisibilityFilter.public => w.visibility == WishlistVisibility.public,
    _VisibilityFilter.private => w.visibility == WishlistVisibility.private,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wishlistsProvider);
    final colors = context.colors;
    final all = state.wishlists;

    if (all == null) {
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
                        ref.read(wishlistsProvider.notifier).refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
    }

    final visible = all.where((w) => _matches(w, filter)).toList();
    final shared = state.sharedWithMe ?? const <Wishlist>[];

    return RefreshIndicator(
      onRefresh: () => ref.read(wishlistsProvider.notifier).refresh(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All (${all.length})',
                  selected: filter == _VisibilityFilter.all,
                  onTap: () => onFilterChanged(_VisibilityFilter.all),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label:
                      'Public (${all.where((w) => w.visibility == WishlistVisibility.public).length})',
                  selected: filter == _VisibilityFilter.public,
                  onTap: () => onFilterChanged(_VisibilityFilter.public),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label:
                      'Private (${all.where((w) => w.visibility == WishlistVisibility.private).length})',
                  selected: filter == _VisibilityFilter.private,
                  onTap: () => onFilterChanged(_VisibilityFilter.private),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty && shared.isEmpty
                ? Center(
                    child: Text(
                      all.isEmpty
                          ? 'Create your first wishlist to get started.'
                          : 'No wishlists match this filter.',
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.huge,
                    ),
                    children: [
                      for (final wishlist in visible) ...[
                        WishlistCard(
                          wishlist: wishlist,
                          onTap: () => context.push(
                            AppRoutes.wishlistDetail(wishlist.id),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      // The only place you can gift from — your own lists
                      // always refuse. Hidden entirely when nobody has shared
                      // anything, rather than shown as an empty heading.
                      if (shared.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Shared with you',
                          style: context.text.titleMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final wishlist in shared) ...[
                          WishlistCard(
                            wishlist: wishlist,
                            onTap: () => context.push(
                              AppRoutes.wishlistDetail(wishlist.id),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
