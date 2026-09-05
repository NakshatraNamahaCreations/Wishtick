import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../../group_gift/domain/group_gift.dart';
import '../../../wishlist/domain/wishlist.dart';
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
/// "Chip in" opens the group gift's own screen, where the contribute sheet
/// lives (Sprint 6b).
class GroupGiftCard extends StatelessWidget {
  const GroupGiftCard({
    required this.gift,
    required this.title,
    required this.onChipIn,
    super.key,
  });

  /// The card's own celebration photograph — the frame's export, balloons,
  /// cake and gift already arranged down its right-hand side.
  ///
  /// Not a flat fill built from tokens: the artwork *is* the design, and the
  /// empty gold field on its left is the space the copy is laid into. Named
  /// for the frame it came from, as the other banners in this file are.
  static const artwork = "assets/images/Home_page_banners/Ananya's 24th.png";

  /// The share of the width the copy may use, leaving the rest to the cake and
  /// the balloons. Anything wider runs underneath them and stops being legible.
  static const _copyFlex = 3;
  static const _artworkFlex = 2;

  final GroupGift gift;

  /// What the gift is for. The list endpoint carries no item title, so the
  /// caller supplies whatever context it has.
  final String title;
  final VoidCallback onChipIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = gift.daysToDeadline();
    // The artwork is a photograph: it stays gold whichever theme is on, so its
    // ink has to as well. `primaryDeep` is the one dark token that holds in
    // both — and it is the plum the progress bar is already drawn in.
    final ink = colors.primaryDeep;
    final message = gift.message?.trim();

    return Material(
      // Shows through only where `cover` cannot reach; the artwork is the card.
      color: colors.celebrationSubtle,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: Image.asset(
              artwork,
              fit: BoxFit.cover,
              // Crop off the empty gold on the left rather than the artwork on
              // the right: the left is the part the copy covers anyway.
              alignment: Alignment.centerRight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: _copyFlex,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (days != null && days >= 0) WhenPill(daysAway: days),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.headlineSmall?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (message != null && message.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: ink.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                      // Pins the goal and the button to the foot of the card,
                      // however much or little the host wrote above them.
                      const Spacer(),
                      Text(
                        'Group Gift',
                        style: context.text.labelSmall?.copyWith(
                          color: ink.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${formatInrMinor(gift.collectedAmountMinor)} of '
                        '${formatInrMinor(gift.targetAmountMinor)}',
                        style: context.text.titleMedium?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          // Server-computed, so the bar and the amounts cannot
                          // disagree.
                          value: gift.percentFunded / 100,
                          minHeight: 6,
                          backgroundColor: colors.surface.withValues(
                            alpha: 0.6,
                          ),
                          valueColor: AlwaysStoppedAnimation(
                            colors.primaryDeep,
                          ),
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
                ),
                // Left bare on purpose: the cake and the balloons live here.
                const Expanded(flex: _artworkFlex, child: SizedBox.shrink()),
              ],
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
            if (event.artworkUrl != null) ...[
              Positioned.fill(child: WishtickImage(url: event.artworkUrl)),
              const Positioned.fill(child: _CoverScrim()),
            ],
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
            if (wishlist.coverUrl != null) ...[
              Positioned.fill(child: WishtickImage(url: wishlist.coverUrl)),
              const Positioned.fill(child: _CoverScrim()),
            ],
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

/// The wash between a cover photo and the white copy laid over it.
///
/// Without it the title reads only against whatever the photo happens to be:
/// a bright sky, a pale wall or a white product shot leaves white-on-white,
/// which is exactly what a user-supplied cover can be. Darkest at the top,
/// where the title and its subtitle sit, lifting toward the bottom so the
/// picture is still a picture.
///
/// Uses `colors.overlay` — the app's black scrim token — rather than a literal
/// black, so it follows the theme the way the sheet and dialog scrims do.
class _CoverScrim extends StatelessWidget {
  const _CoverScrim();

  @override
  Widget build(BuildContext context) {
    final scrim = context.colors.overlay;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scrim, scrim.withValues(alpha: 0.12)],
        ),
      ),
    );
  }
}

/// The two editorial banners between Home's rails (`51:11`) — both baked as
/// complete flattened artwork (background, copy and illustration all in one
/// PNG) rather than recreated in Flutter: the wording, typography and art
/// are a single inseparable design, and rebuilding it from tokens would
/// drift the moment either changed.
class CelebrateMomentBanner extends StatelessWidget {
  const CelebrateMomentBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Celebrate Every Moment. '
          "From life's biggest milestones to everyday joys.",
      child: const AspectRatio(
        aspectRatio: 552 / 185,
        child: Image(
          image: AssetImage(
            'assets/images/Home_page_banners/Celebration spotlight banner.png',
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class BirthdaysBanner extends StatelessWidget {
  const BirthdaysBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Birthdays Made Special. Never lose track of the gifts you love.',
      child: const AspectRatio(
        aspectRatio: 567 / 245,
        child: Image(
          image: AssetImage(
            'assets/images/Home_page_banners/Birthday spotlight banner.png',
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
