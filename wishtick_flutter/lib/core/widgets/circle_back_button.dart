import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/theme_extensions.dart';

/// The white disc with a chevron that the Sprint 7 frames use instead of a
/// bare app-bar arrow (`257:755`, `263:900`, `263:1014`, `2248:70`).
///
/// A widget rather than four copies: the disc, its size and its elevation are
/// the same on every one of those screens, and a fifth would otherwise drift.
class CircleBackButton extends StatelessWidget {
  const CircleBackButton({this.onTap, super.key});

  /// Defaults to popping the route, which is what every frame's chevron does.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: colors.shadow,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            Icons.arrow_back_ios_new,
            size: AppSizes.iconMd,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// A transparent app bar carrying [CircleBackButton], and optionally a centred
/// title — the two arrangements the Sprint 7 frames use.
AppBar circleBackAppBar(
  BuildContext context, {
  String? title,
  List<Widget>? actions,
}) => AppBar(
  // The page colour rather than transparent: an app bar with no colour of its
  // own leaves the status-bar strip showing whatever is behind the route,
  // which on a route pushed over a translucent one is the dimming scrim.
  backgroundColor: context.colors.background,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  centerTitle: true,
  title: title == null
      ? null
      : Text(
          title,
          style: context.text.titleMedium?.copyWith(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
  leadingWidth: AppSizes.minTapTarget + AppSpacing.lg,
  leading: const Padding(
    padding: EdgeInsets.only(left: AppSpacing.lg),
    child: Align(child: CircleBackButton()),
  ),
  actions: actions,
);
