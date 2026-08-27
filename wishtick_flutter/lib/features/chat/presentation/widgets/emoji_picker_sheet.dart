import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// The chat composer's emoji keyboard.
///
/// The smiley used to append a single 🙂 — one hardcoded character, which is a
/// stand-in rather than a feature. This is the whole set: categorised,
/// searchable, skin-tone aware, with a recents row that fills in as it is used.
///
/// [emoji_picker_flutter] rather than a hand-rolled grid, because the hard part
/// is not the layout. It is knowing which of ~1800 codepoints the running
/// Android version can actually draw — the rest render as tofu boxes — and the
/// package checks the platform and drops those.
Future<void> showEmojiPickerSheet(
  BuildContext context, {
  required TextEditingController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    // The grid is a fixed height and the sheet is sized to it, so the default
    // half-screen cap would crop the category bar off the bottom.
    isScrollControlled: true,
    builder: (context) => EmojiPickerSheet(controller: controller),
  );
}

@visibleForTesting
class EmojiPickerSheet extends StatelessWidget {
  const EmojiPickerSheet({required this.controller, super.key});

  /// Written into directly: the package inserts at the caret and handles
  /// backspace itself, which is what makes it behave like a keyboard rather
  /// than a series of appends.
  final TextEditingController controller;

  /// Tall enough for four rows plus the category and search bars — the point
  /// at which it reads as a keyboard rather than a strip.
  static const height = 320.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        child: SizedBox(
          height: height,
          child: EmojiPicker(
            textEditingController: controller,
            config: Config(
              height: height,
              // Every colour comes from the theme rather than the package's
              // own defaults, which are a fixed light grey that turns into a
              // bright slab in dark mode.
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: colors.surface,
                columns: 8,
                emojiSizeMax: 28,
                gridPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                noRecents: Text(
                  'No recent emoji',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: colors.surface,
                iconColor: colors.textMuted,
                iconColorSelected: colors.primary,
                indicatorColor: colors.primary,
                dividerColor: colors.border,
                backspaceColor: colors.primary,
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                backgroundColor: colors.surfaceAlt,
                buttonColor: colors.surfaceAlt,
                buttonIconColor: colors.textSecondary,
              ),
              searchViewConfig: SearchViewConfig(
                backgroundColor: colors.surface,
                buttonIconColor: colors.textSecondary,
                hintTextStyle: context.text.bodyMedium?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              skinToneConfig: SkinToneConfig(
                dialogBackgroundColor: colors.surface,
                indicatorColor: colors.border,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
