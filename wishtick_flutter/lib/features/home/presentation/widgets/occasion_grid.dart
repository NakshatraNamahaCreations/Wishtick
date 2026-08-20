import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// One tile on Home's celebration grid.
typedef OccasionTile = ({String key, String label, String image});

/// The eight tiles Home shows (Figma `51:11`), in the mock's order.
///
/// Every key is a real `occasion` taxonomy row — `rakhi` and `best_wishes`
/// were seeded for this grid rather than pointed at a near-miss, so a tile's
/// label always matches the key it filters by. "Custom Events" is the one
/// exception: it is an action, not an occasion, and is handled separately —
/// it has no photo among `assets/images/Celebrations_images/`, and stays the
/// highlighted sparkle-icon tile it already was.
const kHomeOccasions = <OccasionTile>[
  (
    key: 'birthday',
    label: 'Birthday',
    image: 'assets/images/Celebrations_images/Birthday.png',
  ),
  (
    key: 'anniversary',
    label: 'Anniversary',
    image: 'assets/images/Celebrations_images/Anniversary.png',
  ),
  (
    key: 'wedding',
    label: 'Wedding',
    image: 'assets/images/Celebrations_images/Wedding.png',
  ),
  (
    key: 'housewarming',
    label: 'House Warming',
    image: 'assets/images/Celebrations_images/House_Warming.png',
  ),
  (
    key: 'baby_shower',
    label: 'Mom to Be',
    image: 'assets/images/Celebrations_images/Mom_to_Be.png',
  ),
  (
    key: 'rakhi',
    label: 'Rakhi',
    image: 'assets/images/Celebrations_images/Rakhi.png',
  ),
  (
    key: 'best_wishes',
    label: 'Best Wishes',
    image: 'assets/images/Celebrations_images/Best_Wishes.png',
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
          image: kHomeOccasions[i].image,
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
    required this.onTap,
    this.image,
    this.icon,
    this.highlighted = false,
  }) : assert(
         (image == null) != (icon == null),
         'a tile is either a photo or an icon, never both/neither',
       );

  final String label;
  final String? image;
  final IconData? icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image != null) {
      return _PhotoTile(label: label, image: image, onTap: onTap);
    }

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

/// A photo-backed tile — no card fill, matching the mock: the image's own
/// rounded corners are the whole tile, with the caption sitting bare on the
/// page below it.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.label,
    required this.image,
    required this.onTap,
  });

  final String label;
  final String image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.asset(
                  image,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
