import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/wishtick_image.dart';
import '../../domain/wishlist_item.dart';

/// The shared body of "Product Details" — Figma `280:300` (owner) and
/// `291:1170` (a friend's list).
///
/// The two frames are the same page down to the last row of the gift summary;
/// only the buttons underneath differ. Kept in one place so a change to the
/// summary card can't land on one screen and miss the other.

String importanceLabel(ItemImportance importance) => switch (importance) {
  ItemImportance.mustHave => 'Must have',
  ItemImportance.wouldLove => 'Would love',
  ItemImportance.niceToHave => 'Nice to have',
};

String importancePriority(ItemImportance importance) => switch (importance) {
  ItemImportance.mustHave => 'High priority',
  ItemImportance.wouldLove => 'Medium priority',
  ItemImportance.niceToHave => 'Low priority',
};

/// Image, title, price, and the optional "Why I picked this gift" note.
class ProductDetailHeader extends StatelessWidget {
  const ProductDetailHeader({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.amountMinor,
    required this.notes,
    super.key,
  });

  final String title;

  /// The catalogue's own one-liner. Null on a hand-added item, where there is
  /// nothing to say that the title does not already.
  final String? subtitle;
  final String? imageUrl;
  final int? amountMinor;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: WishtickImage(
            url: imageUrl,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: context.text.headlineSmall?.copyWith(
            color: colors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        // The mock shows a 4.2★ (200 reviews) line here. Wishtick has no
        // ratings API and no review store, so there is nothing to render —
        // a fixed number would be a fabricated review score.
        const SizedBox(height: AppSpacing.sm),
        Text(
          formatInrMinor(amountMinor),
          style: context.text.headlineSmall?.copyWith(
            color: colors.textPrimary,
          ),
        ),
        Text(
          'Inclusive of all taxes',
          style: context.text.bodySmall?.copyWith(color: colors.textMuted),
        ),
        if (notes != null && notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          WhyThisGiftCard(notes: notes!),
        ],
      ],
    );
  }
}

/// The "Gift summary" table.
///
/// Rows with nothing behind them are dropped rather than shown empty: an item
/// added without a recipient has no recipient, and a blank row would read as a
/// loading failure.
class GiftSummaryCard extends StatelessWidget {
  const GiftSummaryCard({
    required this.recipientName,
    required this.occasionLabel,
    required this.wishlistTitle,
    required this.importance,
    required this.createdAt,
    this.addedBy,
    super.key,
  });

  final String? recipientName;
  final String? occasionLabel;
  final String? wishlistTitle;
  final ItemImportance importance;
  final DateTime createdAt;

  /// Who added the item. Only the owner's own screen can say "You" — the item
  /// view carries no author, so a friend's screen passes null and gets the
  /// date alone rather than a guess.
  final String? addedBy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final added = DateFormat("'Added on' d MMM yyyy").format(createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gift summary',
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            children: [
              if (recipientName != null)
                SummaryRow(
                  label: 'Recipient',
                  child: IconValue(
                    icon: Icons.person_outline,
                    text: recipientName!,
                  ),
                ),
              if (occasionLabel != null)
                SummaryRow(label: 'Occasion', child: Text(occasionLabel!)),
              if (wishlistTitle != null)
                SummaryRow(label: 'Wishlist', child: Text(wishlistTitle!)),
              SummaryRow(
                label: 'Priority',
                child: IconValue(
                  icon: Icons.favorite,
                  iconColor: colors.heartFill,
                  text: importanceLabel(importance),
                  caption: importancePriority(importance),
                ),
              ),
              SummaryRow(
                label: 'Added on',
                caption: addedBy == null ? null : added,
                isLast: true,
                child: Text(addedBy ?? added, textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WhyThisGiftCard extends StatelessWidget {
  const WhyThisGiftCard({required this.notes, super.key});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            decoration: BoxDecoration(
              color: colors.accentSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.card_giftcard, color: colors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why I picked this gift',
                  style: context.text.titleSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  notes,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  const SummaryRow({
    required this.label,
    required this.child,
    this.caption,
    this.isLast = false,
    super.key,
  });

  final String label;
  final Widget child;
  final String? caption;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DefaultTextStyle.merge(
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                child: child,
              ),
              if (caption != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  caption!,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textMuted,
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

class IconValue extends StatelessWidget {
  const IconValue({
    required this.icon,
    required this.text,
    this.iconColor,
    this.caption,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color? iconColor;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconSm, color: iconColor ?? colors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(text),
      ],
    );
  }
}
