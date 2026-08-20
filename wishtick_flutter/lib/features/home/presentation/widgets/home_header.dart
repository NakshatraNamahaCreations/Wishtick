import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../addresses/domain/address.dart';

/// Home's plum header (Figma `51:11`): wordmark, delivery location, the
/// add-friend/request-sent/notification icons, and the search field.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.address,
    required this.onLocationTap,
    required this.onSearchTap,
    required this.onNotificationsTap,
    this.unreadCount = 0,
    super.key,
  });

  /// Null renders "Location Missing", exactly as the mock shows it.
  final Address? address;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationsTap;

  /// How many notifications are unread. Zero draws a bare bell.
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final saved = address;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: context.gradients.header,
        // The mock's header is its own rounded card, not a full-bleed
        // rectangle — the page's beige shows through the corners below it.
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xxl),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xxl),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Image(
                      image: AssetImage('assets/logo/logo.png'),
                      width: AppSizes.brandMark,
                      height: AppSizes.brandMark,
                    ),
                    // Tight: the asset's own transparent margin already
                    // holds the mark off the wordmark.
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'WISHTICK',
                      style: context.text.titleLarge?.copyWith(
                        color: colors.textOnDark,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onLocationTap,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                // The mock shows India's flag beside the
                                // delivery header — a plain emoji glyph, so
                                // no asset is needed for a locale this app
                                // does not yet vary by.
                                const Text(
                                  '🇮🇳',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Text(
                                    'Where To Deliver?',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleSmall?.copyWith(
                                      color: colors.textOnDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    saved == null
                                        ? 'Location Missing'
                                        : '${saved.label.display} · ${saved.shortLine}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.bodySmall?.copyWith(
                                      color: colors.textOnDark.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: AppSizes.iconSm,
                                  color: colors.textOnDark.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Add-friend and request-sent are the design's marks for
                    // features no sprint has built yet, so they are drawn
                    // but not wired: a tap that only apologises is worse
                    // than one that does nothing. They become buttons when
                    // there is somewhere for them to go.
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      child: Image(
                        image: AssetImage('assets/icons/add_friend.png'),
                        width: AppSizes.iconLg,
                        height: AppSizes.iconLg,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      child: Image(
                        image: AssetImage('assets/icons/request_sent.png'),
                        width: AppSizes.iconLg,
                        height: AppSizes.iconLg,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      onPressed: onNotificationsTap,
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            color: colors.textOnDark,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                constraints: const BoxConstraints(minWidth: 16),
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  textAlign: TextAlign.center,
                                  style: context.text.labelSmall?.copyWith(
                                    color: colors.onAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // A button rather than a live field: tapping opens the
                // search screen, so there is no keyboard focus to manage
                // here.
                InkWell(
                  onTap: onSearchTap,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    height: AppSizes.inputHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: colors.textOnDark.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: colors.textOnDark.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: colors.textOnDark.withValues(alpha: 0.8),
                          size: AppSizes.iconMd,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        // Flexible so a longer (or localized) hint
                        // ellipsizes instead of overflowing the field.
                        Flexible(
                          child: Text(
                            'Search friends, events, wishlists, gifts...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(
                              color: colors.textOnDark.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
