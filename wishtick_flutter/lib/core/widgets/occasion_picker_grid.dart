import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/theme_extensions.dart';
import 'selection_caret.dart';

/// Artwork for the eight occasions, by their **label**.
///
/// By label rather than by key on purpose: event creation and memory creation
/// show the same eight occasions in the same order, but under different key
/// vocabularies — `house_warming` against `housewarming`, `custom` against
/// `just_because`. Two key-shaped tables is exactly how the two grids drifted
/// apart in the first place, so the label — the thing genuinely common to both
/// — is what resolves the picture.
///
/// The last two are deliberately crossed: the frame's "Custom Events" is the
/// bouquet and its "Best Wishes" is the gift box, while the filenames follow
/// Home's grid.
const kOccasionArtwork = <String, String>{
  'Birthday': 'assets/images/Celebrations_images/Birthday.png',
  'Anniversary': 'assets/images/Celebrations_images/Anniversary.png',
  'Wedding': 'assets/images/Celebrations_images/Wedding.png',
  'House Warming': 'assets/images/Celebrations_images/House_Warming.png',
  'Mom to Be': 'assets/images/Celebrations_images/Mom_to_Be.png',
  'Custom Events': 'assets/images/Celebrations_images/Best_Wishes.png',
  'Rakhi': 'assets/images/Celebrations_images/Rakhi.png',
  'Best Wishes': 'assets/images/Celebrations_images/Just_Because.png',
};

/// The illustrated occasion picker shared by event creation (`257:733`) and
/// memory creation (`4104:1539`).
///
/// One widget rather than one per screen: the two frames draw the same grid,
/// and when they were two copies the memory screen kept the stand-in glyphs
/// after the event screen got its photographs.
class OccasionPickerGrid extends StatelessWidget {
  const OccasionPickerGrid({
    required this.occasions,
    required this.selectedKey,
    required this.onSelect,
    super.key,
  });

  /// The occasions to draw, in the frame's reading order. The key is what
  /// [onSelect] reports and what [selectedKey] is matched against; the label
  /// is both the caption and the artwork lookup.
  final List<({String key, String label})> occasions;

  final String selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.lg,
      crossAxisSpacing: AppSpacing.lg,
      // 100 wide over a 92 tile plus its caption, as the frames measure.
      childAspectRatio: 0.89,
      children: [
        for (final occasion in occasions)
          OccasionCard(
            label: occasion.label,
            photo: kOccasionArtwork[occasion.label],
            selected: occasion.key == selectedKey,
            onTap: () => onSelect(occasion.key),
          ),
      ],
    );
  }
}

/// One tile of [OccasionPickerGrid] — the artwork, its caption, and the caret
/// that marks the selection.
@visibleForTesting
class OccasionCard extends StatelessWidget {
  const OccasionCard({
    required this.label,
    required this.photo,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;

  /// Null falls back to a neutral glyph — an occasion with no artwork should
  /// still be pickable rather than render an empty card.
  final String? photo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Stack(
            // The caret hangs past the tile's foot, into the gap above the
            // label — clipped, it would be sliced off flat.
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            // Without this the loose stack would shrink the tile to its
            // artwork instead of filling the grid cell.
            fit: StackFit.expand,
            children: [
              Material(
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
                    // Inset by the border so the artwork never sits under it,
                    // and clipped to the inner radius so a square photo cannot
                    // square off the card's corners.
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: photo == null
                        ? IconTheme(
                            data: IconThemeData(
                              size: AppSizes.iconLg + AppSpacing.md,
                              color: selected
                                  ? colors.primary
                                  : colors.primaryMuted,
                            ),
                            child: const Icon(Icons.celebration_outlined),
                          )
                        : Image.asset(photo!, fit: BoxFit.contain),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  bottom: -SelectionCaret.overhang,
                  child: SelectionCaret(color: colors.primary),
                ),
            ],
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
