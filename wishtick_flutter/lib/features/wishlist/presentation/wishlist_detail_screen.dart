import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/relative_time.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../wishmates/presentation/widgets/quick_share_sheet.dart';
import '../domain/wishlist.dart';
import '../domain/wishlist_item.dart';
import 'share_wishlist_screen.dart';
import 'widgets/wishlist_item_card.dart';
import 'wishlist_detail_controller.dart';

/// Figma `280:212` — one wishlist's own detail page (owner view).
class WishlistDetailScreen extends ConsumerStatefulWidget {
  const WishlistDetailScreen({required this.wishlistId, super.key});

  final String wishlistId;

  @override
  ConsumerState<WishlistDetailScreen> createState() =>
      _WishlistDetailScreenState();
}

class _WishlistDetailScreenState extends ConsumerState<WishlistDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(wishlistDetailProvider(widget.wishlistId).notifier)
          .ensureLoaded(),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete wishlist?'),
        content: const Text(
          'This removes the wishlist and all of its items. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(wishlistDetailProvider(widget.wishlistId).notifier)
        .archive();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final error = ref.read(wishlistDetailProvider(widget.wishlistId)).error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  /// Opens the quick-share sheet — a grid of WishMates rather than a screen
  /// asking for an email address.
  ///
  /// Everyone who can be given access is already a connection, so there is
  /// nothing to type; a public list additionally offers its link. The old
  /// [ShareWishlistScreen] remains the place for the *settings* behind a share
  /// (visibility, passcode, expiry), reached from the access row.
  Future<void> _share() async {
    final wishlist = ref
        .read(wishlistDetailProvider(widget.wishlistId))
        .wishlist;
    if (wishlist == null) return;
    await showQuickShareSheet(
      context,
      WishlistShareTarget(
        wishlistId: wishlist.id,
        title: wishlist.title,
        slug: wishlist.share?.slug,
        // `event_only` and `private` both admit nobody by link — only the
        // people explicitly given access — so neither offers one.
        isPublic:
            wishlist.visibility == WishlistVisibility.public ||
            wishlist.visibility == WishlistVisibility.inviteOnly,
      ),
    );
  }

  Future<void> _sortBy() async {
    final chosen = await showModalBottomSheet<ItemSort>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final sort in ItemSort.values)
              ListTile(
                title: Text(sort.label),
                onTap: () => Navigator.of(context).pop(sort),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    ref.read(wishlistDetailProvider(widget.wishlistId).notifier).sortBy(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wishlistDetailProvider(widget.wishlistId));
    final colors = context.colors;
    final wishlist = state.wishlist;
    final items = state.items;

    return Scaffold(
      appBar: AppBar(
        title: wishlist == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    wishlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${wishlist.visibility.label} wishlist',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: SafeArea(
        child: switch ((wishlist, items, state.error)) {
          (null, _, null) => const Center(child: CircularProgressIndicator()),
          (null, _, final String message) => Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WishtickErrorText(message),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => ref
                      .read(wishlistDetailProvider(widget.wishlistId).notifier)
                      .refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          (final Wishlist loaded, final List<WishlistItem>? loadedItems, _) =>
            RefreshIndicator(
              onRefresh: () => ref
                  .read(wishlistDetailProvider(widget.wishlistId).notifier)
                  .refresh(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (loaded.description != null &&
                              loaded.description!.isNotEmpty)
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    loaded.description!,
                                    style: context.text.bodyMedium?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Icon(
                                  Icons.favorite,
                                  color: colors.heartFill,
                                  size: AppSizes.iconSm,
                                ),
                              ],
                            ),
                          // Edit / Share / Delete are owner actions. On a list
                          // shared with you the server refuses all three, so
                          // the whole row — and its spacing — is absent rather
                          // than drawn to fail.
                          if (loaded.access.canManage) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.edit_outlined,
                                    label: 'Edit',
                                    onTap: () => context.push(
                                      '${AppRoutes.wishlistDetail(loaded.id)}/edit',
                                      extra: loaded,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.share_outlined,
                                    label: 'Share',
                                    onTap: _share,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.delete_outline,
                                    label: 'Delete',
                                    color: colors.danger,
                                    onTap: _confirmDelete,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // Its own row rather than a fourth pill: this is
                            // the only way to let anyone into a private list,
                            // and it has a state worth reading — "Private,
                            // link won't work" is the answer to the question
                            // people actually arrive with.
                            _AccessRow(
                              visibility: loaded.visibility,
                              onTap: () => context.push(
                                AppRoutes.wishlistAccess(loaded.id),
                                extra: loaded,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${loaded.itemCount} items · Updated ${relativeTime(loaded.updatedAt)}',
                                  style: context.text.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _sortBy,
                                icon: const Icon(Icons.swap_vert),
                                label: const Text('Sort By'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (loadedItems == null)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxl),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (loadedItems.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Center(
                          child: Text(
                            'No items yet.',
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: AppSpacing.md,
                              crossAxisSpacing: AppSpacing.md,
                              childAspectRatio: 0.62,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = loadedItems[index];
                          return WishlistItemCard(
                            item: item,
                            // Someone else's list opens the gifting page;
                            // your own opens the edit/remove one. The server's
                            // access decision picks, not a guess here.
                            onTap: () => context.push(
                              loaded.access.canGift
                                  ? AppRoutes.giftItem(loaded.id, item.id)
                                  : '${AppRoutes.wishlistDetail(loaded.id)}'
                                        '/items/${item.id}',
                            ),
                            onDelete: loaded.access.canManage
                                ? () => ref
                                      .read(
                                        wishlistDetailProvider(
                                          widget.wishlistId,
                                        ).notifier,
                                      )
                                      .removeItem(item.id)
                                : null,
                          );
                        }, childCount: loadedItems.length),
                      ),
                    ),
                ],
              ),
            ),
        },
      ),
    );
  }
}

/// A compact icon+label outlined pill — plain [OutlinedButton.icon] wraps to
/// two lines in a three-across row, so this trims padding and forces one line.
/// "Private · Only people you invite can view it" → the access screen.
///
/// Owner-only, and deliberately wordy: the visibility setting is the single
/// most misread thing about a wishlist, and this row is where someone lands
/// when they are trying to work out why a friend cannot open their link.
class _AccessRow extends StatelessWidget {
  const _AccessRow({required this.visibility, required this.onTap});

  final WishlistVisibility visibility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                visibility.linkGrantsAccess ? Icons.link : Icons.lock_outline,
                size: AppSizes.iconMd,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      visibility.label,
                      style: context.text.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      visibility.summary,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: AppSizes.iconMd,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = color ?? colors.textPrimary;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
