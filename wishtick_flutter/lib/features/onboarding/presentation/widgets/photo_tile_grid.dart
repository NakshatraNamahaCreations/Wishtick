import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/onboarding_options.dart';

/// The three-column photo-tile grid used by the interests screens (Figma
/// `36:839` and the category details): rounded photo, label underneath,
/// selected = plum border + check badge.
///
/// Tiles look for `assets/onboarding/<key>.png`. The top-level interest
/// categories (`fashion`, `technology`, …) have exported artwork; the
/// granular interests inside each category detail screen do not yet, so
/// those fall back to a themed wash with the label's initial — layout and
/// behaviour are exact, imagery pending for that tier.
class PhotoTileGrid extends StatelessWidget {
  const PhotoTileGrid({
    required this.options,
    required this.selectedKeys,
    required this.onToggle,
    super.key,
  });

  final List<TaxonomyOption> options;
  final Set<String> selectedKeys;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.xl,
        // Tile ≈ 100px photo + two lines of label, per the design.
        childAspectRatio: 0.72,
      ),
      itemCount: options.length,
      itemBuilder: (context, i) {
        final option = options[i];
        return PhotoTile(
          option: option,
          selected: selectedKeys.contains(option.key),
          onTap: () => onToggle(option.key),
        );
      },
    );
  }
}

class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final TaxonomyOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelStyle = context.text.labelMedium?.copyWith(
      color: colors.textPrimary,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    // Reserved regardless of how many lines this label actually wraps to. A
    // Column with a fixed total height (the GridView cell) hands its Expanded
    // child whatever the label *doesn't* use — so a one-line label like
    // "Automotive" left its photo taller than a two-line one like "Fashion &
    // Personal Style", even though every cell is the same bounding box.
    final labelHeight =
        (labelStyle?.fontSize ?? 13) * (labelStyle?.height ?? 1.2) * 2;

    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                // expand, so the tile gets a *tight* box on both axes. Loose
                // by default, the image would size to its own pixels and a
                // real photo would letterbox instead of filling the tile.
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: selected
                          ? Border.all(color: colors.primary, width: 2)
                          : null,
                      color: colors.surface,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md - 2),
                      child: Image.asset(
                        'assets/onboarding/${option.key}.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _TilePlaceholder(label: option.label),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                        child: Icon(
                          Icons.check,
                          size: AppSizes.iconSm,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: labelHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for the unexported tile photography.
class _TilePlaceholder extends StatelessWidget {
  const _TilePlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ColoredBox(
      color: colors.accentSubtle,
      child: Center(
        child: Text(
          label.isEmpty ? '?' : label[0],
          style: context.text.headlineLarge?.copyWith(color: colors.accent),
        ),
      ),
    );
  }
}
