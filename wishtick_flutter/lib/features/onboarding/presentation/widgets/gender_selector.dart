import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/profile_draft.dart';

/// Three gender tiles — Figma `31:608`.
///
/// The selected tile fills with plum, inverts its text and carries a check
/// badge in the top-right corner; the others are flat white, per the Figma
/// design — no hairline. On the beige page that leaves the tile barely a shade
/// off the background until it is either tapped or scanned by touch, which is
/// the trade-off of matching the design exactly here.
class GenderSelector extends StatelessWidget {
  const GenderSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Gender? value;
  final ValueChanged<Gender> onChanged;

  /// Widgets rather than [IconData]: Male and Female use Material glyphs, but
  /// Other is the brand asset, and [Icon]/[ImageIcon] both take their size and
  /// colour from the ambient [IconTheme] `_Tile` applies, so either can sit
  /// here interchangeably.
  static const _icons = <Gender, Widget>{
    Gender.male: Icon(Icons.male),
    Gender.female: Icon(Icons.female),
    Gender.other: ImageIcon(AssetImage(_othersAsset)),
  };

  static const _othersAsset = 'assets/icons/others.png';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final gender in Gender.values) ...[
          if (gender != Gender.values.first)
            const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _Tile(
              gender: gender,
              icon: _icons[gender]!,
              selected: value == gender,
              onTap: () => onChanged(gender),
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.gender,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final Gender gender;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  static const _height = 72.0;

  /// The check disc sits *astride* the tile's top edge — measured at Ø30 with
  /// its right edge flush to the tile's and 5px of it above the top edge.
  static const _badgeSize = 30.0;
  static const _badgeRise = -5.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.onPrimary : colors.primaryMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: gender.label,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              // Expanded gives this Stack a tight width, but StackFit.loose
              // loosens it again for non-positioned children — without a width
              // the card shrinks to its icon and hugs the left of its slot.
              width: double.infinity,
              height: _height,
              decoration: BoxDecoration(
                color: selected ? colors.primary : colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(
                      size: AppSizes.iconLg,
                      color: foreground,
                    ),
                    child: icon,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    gender.label,
                    textAlign: TextAlign.center,
                    style: context.text.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              // A white disc carrying a plum check — not the inverse. Drawing
              // it as `Icons.check_circle` in plum over a white ring gives a
              // filled plum disc with a white tick, which is not the design.
              Positioned(
                top: _badgeRise,
                right: 0,
                child: Container(
                  width: _badgeSize,
                  height: _badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface,
                  ),
                  child: Icon(
                    Icons.check,
                    size: AppSizes.iconSm,
                    color: colors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
