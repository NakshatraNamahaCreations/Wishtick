import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../../wishlist/domain/wishlist.dart';
import '../../domain/group_gift.dart';
import '../../domain/wishtick_event.dart';

/// A short "In 3 days" / "Today" pill, shared by the gift and event cards.
class WhenPill extends StatelessWidget {
  const WhenPill({required this.daysAway, super.key});

  final int daysAway;

  String get _label => switch (daysAway) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => 'In $daysAway days',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: AppSizes.iconSm,
            color: colors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _label,
            style: context.text.labelSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The gold chip-in card (Figma `51:11`) — goal, raised, and a progress bar.
///
/// Read-only this sprint: contributing is Sprint 6, so "Chip in" says so
/// rather than opening a flow that does not exist.
class GroupGiftCard extends StatelessWidget {
  const GroupGiftCard({
    required this.gift,
    required this.title,
    required this.onChipIn,
    super.key,
  });

  final GroupGift gift;

  /// What the gift is for. The list endpoint carries no item title, so the
  /// caller supplies whatever context it has.
  final String title;
  final VoidCallback onChipIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = gift.daysToDeadline();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        // The gold treatment the mock uses. `gradients.celebration` is the
        // plum sweep — a different token for a different card.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.celebrationSubtle, colors.celebration],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (days != null && days >= 0) WhenPill(daysAway: days),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Group Gift',
            style: context.text.labelSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${formatInrMinor(gift.collectedAmountMinor)} of '
            '${formatInrMinor(gift.targetAmountMinor)}',
            style: context.text.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              // Server-computed, so the bar and the amounts cannot disagree.
              value: gift.percentFunded / 100,
              minHeight: 6,
              backgroundColor: colors.surface.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(colors.primaryDeep),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: onChipIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chip in',
                      style: context.text.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: AppSizes.iconSm,
                      color: colors.textPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One card on the "Upcoming Events" rail.
class HomeEventCard extends StatelessWidget {
  const HomeEventCard({required this.event, required this.onTap, super.key});

  final WishtickEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = event.daysAway();

    return Material(
      color: colors.primaryDeep,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (event.coverUrl != null)
              Positioned.fill(child: WishtickImage(url: event.coverUrl)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (days >= 0) WhenPill(daysAway: days),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    event.title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.headlineSmall?.copyWith(
                      color: colors.textOnDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (event.description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      event.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textOnDark.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    // Only the date — the backend has no venue field, so
                    // inventing a location line would be a fabrication.
                    DateFormat('d MMMM yyyy').format(event.startsAt),
                    style: context.text.labelSmall?.copyWith(
                      color: colors.textOnDark.withValues(alpha: 0.85),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card on the "Your Wishlist" rail.
class HomeWishlistCard extends StatelessWidget {
  const HomeWishlistCard({
    required this.wishlist,
    required this.onTap,
    super.key,
  });

  final Wishlist wishlist;
  final VoidCallback onTap;

  static String _visibilityLabel(WishlistVisibility v) => switch (v) {
    WishlistVisibility.public => 'Public',
    WishlistVisibility.private => 'Private',
    WishlistVisibility.eventOnly => 'Event',
    WishlistVisibility.inviteOnly => 'Invite only',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final itemWord = wishlist.itemCount == 1 ? 'item' : 'items';

    return Material(
      color: colors.primaryDeep,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (wishlist.coverUrl != null)
              Positioned.fill(child: WishtickImage(url: wishlist.coverUrl)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    wishlist.title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.headlineSmall?.copyWith(
                      color: colors.textOnDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_visibilityLabel(wishlist.visibility)} · '
                    '${wishlist.itemCount} $itemWord',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textOnDark.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Wishlist',
                          style: context.text.labelSmall?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: AppSizes.iconSm,
                          color: colors.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two editorial banners between Home's rails.
///
/// Rendered as themed gradient cards: the mock's artwork is not among the
/// exported assets, and an invented image would misrepresent the design.
class PromoBanner extends StatelessWidget {
  const PromoBanner({
    required this.title,
    required this.body,
    this.onDark = true,
    super.key,
  });

  final String title;
  final String body;

  /// Plum-on-dark (the first banner) or the light celebration treatment.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = onDark ? colors.textOnDark : colors.textPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        // `gradients.celebration` rather than `headline`: headline's dark-mode
        // stops are both light, which would leave this card's ivory text
        // unreadable. Celebration stays plum-dark in both themes.
        gradient: onDark ? context.gradients.celebration : null,
        color: onDark ? null : colors.celebrationSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.text.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: context.text.bodySmall?.copyWith(
              color: onDark
                  ? foreground.withValues(alpha: 0.85)
                  : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
