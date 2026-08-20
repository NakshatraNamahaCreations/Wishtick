import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../../wishlist/domain/product.dart';
import '../../domain/discover_feed.dart';
import 'discover_explore_more_button.dart';

/// A `Gift suggestions for X's <Occasion>` shelf (`280:131`) — a bordered
/// white card carrying the saved person, their next date, and up to three
/// suggested products, then a full-width "Explore More".
class DiscoverPersonShelf extends StatelessWidget {
  const DiscoverPersonShelf({
    required this.person,
    required this.items,
    required this.onExplore,
    required this.onProductTap,
    super.key,
  });

  final DiscoverPerson person;
  final List<NormalizedProduct> items;
  final VoidCallback onExplore;
  final ValueChanged<NormalizedProduct> onProductTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // Sampled off the export: a soft shadow, not a hairline border, is
        // what separates this card from the page — same recipe as the
        // onboarding avatar frame (`create_profile_screen.dart`).
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OccasionAvatar(occasionKey: person.occasionKey),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        person.relation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _DatePill(date: person.nextOccurrence),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < items.length && i < 3; i++) ...[
                  if (i != 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _PersonProductTile(
                      product: items[i],
                      onTap: () => onProductTap(items[i]),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            DiscoverExploreMoreButton(onPressed: onExplore),
          ],
        ),
      ),
    );
  }
}

/// A circular occasion-appropriate icon.
///
/// The feed's [DiscoverPerson] carries no photo — important dates have never
/// had an avatar-upload step — so this stands in for the illustrative photos
/// the mock shows, rather than fabricating an image that does not exist.
class _OccasionAvatar extends StatelessWidget {
  const _OccasionAvatar({required this.occasionKey});

  final String occasionKey;

  static const _icons = {
    'birthday': Icons.cake_outlined,
    'anniversary': Icons.favorite_outline,
    'wedding': Icons.favorite_outline,
    'baby_shower': Icons.child_care_outlined,
    'housewarming': Icons.home_outlined,
    'graduation': Icons.school_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CircleAvatar(
      radius: AppSizes.avatarMd / 2,
      backgroundColor: colors.primarySubtle,
      child: Icon(
        _icons[occasionKey] ?? Icons.card_giftcard_outlined,
        color: colors.primary,
        size: AppSizes.iconLg,
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: AppSizes.iconSm,
            color: colors.primary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            DateFormat('d MMMM').format(date),
            style: context.text.labelSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of up to three suggestions inside [DiscoverPersonShelf] — bare (no
/// card fill, no save button): the export shows these floating directly on
/// the shelf card's own white background.
class _PersonProductTile extends StatelessWidget {
  const _PersonProductTile({required this.product, required this.onTap});

  final NormalizedProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: WishtickImage(
              url: product.coverImageUrl,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              Text(
                formatInrMinor(product.amountMinor),
                style: AppTypography.price.copyWith(color: colors.textPrimary),
              ),
              if (product.isDiscounted) ...[
                const SizedBox(width: AppSpacing.xxs),
                Flexible(
                  child: Text(
                    formatInrMinor(product.listPriceMinor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.priceStruck.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
