import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// One tile on Home's celebration grid.
typedef OccasionTile = ({String key, String label, IconData icon});

/// The eight tiles Home shows (Figma `51:11`), in the mock's order.
///
/// Every key is a real `occasion` taxonomy row — `rakhi` and `best_wishes`
/// were seeded for this grid rather than pointed at a near-miss, so a tile's
/// label always matches the key it filters by. "Custom Events" is the one
/// exception: it is an action, not an occasion, and is handled separately.
const kHomeOccasions = <OccasionTile>[
  (key: 'birthday', label: 'Birthday', icon: Icons.cake_outlined),
  (key: 'anniversary', label: 'Anniversary', icon: Icons.favorite_outline),
  (key: 'wedding', label: 'Wedding', icon: Icons.church_outlined),
  (key: 'housewarming', label: 'House Warming', icon: Icons.house_outlined),
  (key: 'baby_shower', label: 'Mom to Be', icon: Icons.child_friendly_outlined),
  (key: 'rakhi', label: 'Rakhi', icon: Icons.volunteer_activism_outlined),
  (
    key: 'best_wishes',
    label: 'Best Wishes',
    icon: Icons.card_giftcard_outlined,
  ),
];

/// "What are we celebrating today?" — taps open a shelf of gifts for that
/// occasion; the highlighted "Custom Events" tile starts an event instead.
class OccasionGrid extends StatelessWidget {
  const OccasionGrid({
    required this.onOccasionTap,
    required this.onCustomEventTap,
    super.key,
  });

  final void Function(OccasionTile occasion) onOccasionTap;
  final VoidCallback onCustomEventTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // "Custom Events" sits fifth in the mock's reading order.
    const customIndex = 5;
    final cells = <Widget>[
      for (var i = 0; i < kHomeOccasions.length; i++) ...[
        if (i == customIndex)
          _Tile(
            label: 'Custom Events',
            icon: Icons.auto_awesome_outlined,
            highlighted: true,
            onTap: onCustomEventTap,
          ),
        _Tile(
          label: kHomeOccasions[i].label,
          icon: kHomeOccasions[i].icon,
          onTap: () => onOccasionTap(kHomeOccasions[i]),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What are we celebrating today?',
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Without this the grid inherits the ambient MediaQuery padding and
          // opens a gap under the heading.
          padding: EdgeInsets.zero,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.82,
          children: cells,
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = highlighted ? colors.onPrimary : colors.primary;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: highlighted ? colors.primaryDeep : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: AppSizes.iconLg),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: highlighted ? colors.onPrimary : colors.textPrimary,
                    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
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
