import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/invite_design.dart';

/// The controls for the selected layer: typeface, size, weight, slant,
/// alignment, colour and opacity.
///
/// One panel driven by callbacks rather than by the controller directly, so a
/// widget test can drive it without a ProviderScope and so the "live" edits
/// (the two sliders) can be told apart from the discrete ones. That split is
/// what keeps a slider drag from filling the undo stack.
class InviteStyleBar extends StatelessWidget {
  const InviteStyleBar({
    required this.layer,
    required this.onChange,
    required this.onChangeLive,
    required this.onGestureStart,
    required this.onReorder,
    required this.onDuplicate,
    super.key,
  });

  final TextLayer layer;

  /// A discrete edit — one undo step.
  final ValueChanged<TextLayer> onChange;

  /// A frame of a slider drag — no undo step of its own.
  final ValueChanged<TextLayer> onChangeLive;

  final VoidCallback onGestureStart;
  final void Function({required bool forward}) onReorder;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fontRow(context),
          _sizeRow(
            context,
            'Size',
            Icons.format_size,
            layer.fontSize,
            TextLayer.minFontSize,
            TextLayer.maxFontSize,
            (v) => layer.copyWith(fontSize: v),
          ),
          _sizeRow(
            context,
            'Opacity',
            Icons.opacity,
            layer.opacity,
            0.1,
            1.0,
            (v) => layer.withOpacity(v),
          ),
          _swatchRow(context),
          _toggleRow(context),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xs,
      AppSpacing.lg,
      0,
    ),
    child: Text(
      text,
      style: context.text.labelSmall?.copyWith(color: context.colors.textMuted),
    ),
  );

  Widget _fontRow(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Icon(
            Icons.text_fields,
            size: AppSizes.iconMd,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DropdownButtonFormField<String>(
              // A dropdown, not a rail: there are two dozen faces across four
              // groups now, and a horizontal scroller hides most of them behind
              // a swipe with no hint that they exist.
              initialValue: layer.fontKey,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Font',
              ),
              // Each entry is set in its own face, so the list is legible as
              // itself rather than as a column of names in one typeface.
              items: [
                for (final section in InviteFonts.grouped()) ...[
                  DropdownMenuItem<String>(
                    enabled: false,
                    child: Text(
                      section.group.toUpperCase(),
                      style: context.text.labelSmall?.copyWith(
                        color: colors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  for (final font in section.fonts)
                    DropdownMenuItem<String>(
                      value: font.key,
                      child: Text(
                        font.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _sampleStyle(context, font),
                      ),
                    ),
                ],
              ],
              onChanged: (key) {
                if (key == null) return;
                onChange(layer.copyWith(fontKey: key));
              },
            ),
          ),
        ],
      ),
    );
  }

  /// One list entry, drawn in the face it names.
  ///
  /// A Google face that has not been fetched yet renders in the fallback until
  /// it arrives — which is the honest preview: it is also what the *canvas*
  /// shows until then.
  TextStyle? _sampleStyle(BuildContext context, InviteFont font) {
    final base = context.text.bodyLarge?.copyWith(
      color: context.colors.textPrimary,
    );
    if (font.isBundled) return base?.copyWith(fontFamily: font.family);
    return GoogleFonts.getFont(font.family, textStyle: base);
  }

  Widget _sizeRow(
    BuildContext context,
    String label,
    IconData icon,
    double value,
    double min,
    double max,
    TextLayer Function(double) apply,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppSizes.iconMd,
            color: context.colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              label: label,
              // The drag records one undo step at the start and none after,
              // so an undo returns to the size before the drag rather than
              // stepping back through every intermediate value.
              onChangeStart: (_) => onGestureStart(),
              onChanged: (v) => onChangeLive(apply(v)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _swatchRow(BuildContext context) {
    final colors = context.colors;
    // The host's ink, not the app's chrome — identical in both themes, which is
    // why it is one token rather than a field per colour. See
    // [WishtickColors.inviteInks].
    final swatches = colors.inviteInks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, 'Colour'),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: swatches.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final swatch = swatches[index];
              final selected =
                  (layer.displayColor.toARGB32() & 0x00FFFFFF) ==
                  (swatch.toARGB32() & 0x00FFFFFF);
              return Semantics(
                label: 'Colour ${index + 1}',
                selected: selected,
                button: true,
                child: GestureDetector(
                  onTap: () => onChange(layer.withColor(swatch)),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(
                        // The selected ring has to read against white as well
                        // as against near-black, so it is the app's primary
                        // rather than a lightened version of the swatch.
                        color: selected ? colors.primary : colors.border,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _toggleRow(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _toggle(
            context,
            icon: Icons.format_bold,
            tooltip: 'Bold',
            active: layer.bold,
            onTap: () => onChange(layer.copyWith(bold: !layer.bold)),
          ),
          _toggle(
            context,
            icon: Icons.format_italic,
            tooltip: 'Italic',
            active: layer.italic,
            onTap: () => onChange(layer.copyWith(italic: !layer.italic)),
          ),
          for (final align in LayerAlign.values)
            _toggle(
              context,
              icon: switch (align) {
                LayerAlign.left => Icons.format_align_left,
                LayerAlign.center => Icons.format_align_center,
                LayerAlign.right => Icons.format_align_right,
              },
              tooltip: 'Align ${align.wireValue}',
              active: layer.align == align,
              onTap: () => onChange(layer.copyWith(align: align)),
            ),
          Container(width: 1, height: 24, color: colors.border),
          _toggle(
            context,
            icon: Icons.flip_to_front,
            tooltip: 'Bring forward',
            active: false,
            onTap: () => onReorder(forward: true),
          ),
          _toggle(
            context,
            icon: Icons.flip_to_back,
            tooltip: 'Send backward',
            active: false,
            onTap: () => onReorder(forward: false),
          ),
          _toggle(
            context,
            icon: Icons.copy_all_outlined,
            tooltip: 'Duplicate',
            active: false,
            onTap: onDuplicate,
          ),
        ],
      ),
    );
  }

  Widget _toggle(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required bool active,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? colors.primary : colors.primarySubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            icon,
            size: AppSizes.iconMd,
            color: active ? colors.onPrimary : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
