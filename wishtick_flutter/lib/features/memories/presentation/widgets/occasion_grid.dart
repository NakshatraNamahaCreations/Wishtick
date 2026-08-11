import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/sparkle_icon.dart';
import '../create_memory_controller.dart';

/// The eight illustrated occasion cards on `4104:1539`.
///
/// Drawn with icons rather than the design's illustrations: those are not
/// exported, and a wrong illustration would be worse than an honest glyph. Same
/// substitution, and the same reason, as the event-creation grid.
class OccasionGrid extends StatelessWidget {
  const OccasionGrid({
    required this.selectedKey,
    required this.onSelect,
    super.key,
  });

  final String selectedKey;
  final ValueChanged<String> onSelect;

  /// Widgets rather than [IconData] so the brand sparkle can sit alongside the
  /// Material glyphs. None of them carry a size or colour — the card supplies
  /// both through an [IconTheme], which [Icon] and [SparkleIcon] both read.
  static const _icons = <String, Widget>{
    'birthday': Icon(Icons.cake_outlined),
    'anniversary': Icon(Icons.favorite_border),
    'wedding': Icon(Icons.church_outlined),
    'housewarming': Icon(Icons.home_outlined),
    'baby_shower': Icon(Icons.child_friendly_outlined),
    'just_because': SparkleIcon(),
    'rakhi': Icon(Icons.volunteer_activism_outlined),
    'best_wishes': Icon(Icons.card_giftcard),
  };

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.lg,
      crossAxisSpacing: AppSpacing.lg,
      // 100 wide over a 92 tile plus its caption, as the frame measures.
      childAspectRatio: 0.89,
      children: [
        for (final occasion in kMemoryOccasions)
          _OccasionCard(
            label: occasion.label,
            icon:
                _icons[occasion.key] ?? const Icon(Icons.celebration_outlined),
            selected: occasion.key == selectedKey,
            onTap: () => onSelect(occasion.key),
          ),
      ],
    );
  }
}

class _OccasionCard extends StatelessWidget {
  const _OccasionCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: selected ? colors.primary : colors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: IconTheme(
                  data: IconThemeData(
                    size: AppSizes.iconLg + AppSpacing.md,
                    color: selected ? colors.primary : colors.primaryMuted,
                  ),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: context.text.bodySmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
