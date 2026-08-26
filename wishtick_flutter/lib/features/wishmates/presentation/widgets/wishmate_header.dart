import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/curved_bottom_clipper.dart';

/// The plum masthead with the shallow curved foot that `4177:77`, `4177:111`,
/// `4177:42` and `4177:179` all sit under.
///
/// Measured off the exports: the plum ends at y 122 at the frame's edges and
/// y 129 at its centre, under a status bar the app draws into. Height and sag
/// are therefore 129 and 7 — the deep sweep on `257:733` is the same curve with
/// a much larger dip, which is why [CurvedBottomClipper] is shared and this is
/// not.
class WishmateHeader extends StatelessWidget {
  const WishmateHeader({this.title, this.bottom, super.key});

  /// Centred, beside the back chevron. Null on `4177:42`, whose header carries
  /// the search field instead of a title.
  final String? title;

  /// Drawn below the title row and inside the plum — the search pill.
  final Widget? bottom;

  /// The plum's own height below the status bar, before [bottom] is added.
  static const _barHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topInset = MediaQuery.paddingOf(context).top;

    return ClipPath(
      clipper: const CurvedBottomClipper(dip: CurvedBottomClipper.shallow),
      child: Container(
        width: double.infinity,
        // Sampled down the left edge of `4177:42`: plumShadow → plumRich →
        // plumMuted, the same ramp the profile hero uses. Not
        // `gradients.header`, whose violet-leaning ink reads blue here.
        decoration: BoxDecoration(gradient: context.gradients.eventMasthead),
        padding: EdgeInsets.only(
          top: topInset,
          // The clipper eats into the foot, so the content is held clear of it.
          bottom: CurvedBottomClipper.shallow + AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _barHeight,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      size: AppSizes.iconMd,
                      color: colors.textOnDark,
                    ),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Text(
                            title!,
                            textAlign: TextAlign.center,
                            style: context.text.titleMedium?.copyWith(
                              color: colors.textOnDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  // Balances the chevron so the title sits on the frame's
                  // centre line rather than the remaining space's.
                  const SizedBox(width: AppSizes.minTapTarget),
                ],
              ),
            ),
            if (bottom != null)
              Padding(
                // 12 each side, measured off `4177:42` (x 12 → 380).
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// The white search pill inside a [WishmateHeader] — `4177:42`'s field and
/// `4177:179`'s "Search Chats".
class WishmateSearchField extends StatelessWidget {
  const WishmateSearchField({
    required this.controller,
    required this.hintText,
    this.autofocus = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Measured off `4177:42` and `4177:179`, which both draw it at 48.
  static const _fieldHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Height-constrained and un-filled on purpose. The app's global
    // `InputDecorationTheme` fills its fields with a squared-off background,
    // which drew a 95-px rectangle over this Material's pill and spilled out
    // through the header's curved foot. `4177:42` measures the field at 48.
    return SizedBox(
      height: _fieldHeight,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          // Zero content padding leaves the text riding high in the pill;
          // this puts it back on the centre line.
          textAlignVertical: TextAlignVertical.center,
          style: context.text.bodyMedium?.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: context.text.bodyMedium?.copyWith(
              color: colors.textMuted,
            ),
            filled: false,
            isDense: true,
            prefixIcon: Icon(
              Icons.search,
              size: AppSizes.iconLg,
              color: colors.textSecondary,
            ),
            // Listenable so the clear button appears and disappears with
            // the text without the whole screen rebuilding on every keystroke.
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                      icon: Icon(
                        Icons.close,
                        size: AppSizes.iconMd,
                        color: colors.textSecondary,
                      ),
                      tooltip: 'Clear',
                    ),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            // Zero, because the SizedBox already sets the height and the
            // decoration centres the text within it.
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
