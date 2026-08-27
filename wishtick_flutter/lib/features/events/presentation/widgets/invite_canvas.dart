import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../domain/invite_design.dart';

/// The invitation itself — background and text, and nothing else.
///
/// Deliberately free of selection handles, gesture targets and chrome: the
/// editor stacks those *on top* of this, and the export renders this same
/// widget off-screen. One painter for both is what makes the design the host
/// approves and the PNG the guests receive the same picture. A separate
/// "export layout" is how those two quietly drift apart.
class InviteCanvas extends StatelessWidget {
  const InviteCanvas({
    required this.design,
    required this.width,
    this.backgroundFallback,
    super.key,
  });

  final InviteDesign design;

  /// The canvas width in logical pixels. Everything else is derived from it,
  /// because every value on a [TextLayer] is a fraction of exactly this.
  final double width;

  /// Drawn when the design names a background the app does not ship — an
  /// invitation authored by a newer build, or an asset since renamed.
  final Color? backgroundFallback;

  double get height => width / InviteDesign.aspectRatio;

  @override
  Widget build(BuildContext context) {
    final background = design.background;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (background == null)
            ColoredBox(color: backgroundFallback ?? context.colors.surface)
          else
            Image.asset(
              background.asset,
              fit: BoxFit.cover,
              // The two bundled backgrounds are 9:16 and 2:3; `cover` crops the
              // shorter one rather than letterboxing it, which would put bands
              // of dead colour inside the card the host is designing.
              filterQuality: FilterQuality.high,
            ),
          for (final layer in design.layers)
            InviteTextLayerView(layer: layer, canvasWidth: width),
        ],
      ),
    );
  }
}

/// One text layer, positioned and styled from its fractions.
///
/// Split out so the editor's hit-testing and the plain render agree on exactly
/// where a layer is: the editor wraps this in its gesture detector rather than
/// laying the text out a second time.
class InviteTextLayerView extends StatelessWidget {
  const InviteTextLayerView({
    required this.layer,
    required this.canvasWidth,
    super.key,
  });

  final TextLayer layer;
  final double canvasWidth;

  double get canvasHeight => canvasWidth / InviteDesign.aspectRatio;

  /// The widest the text may get before it wraps, in logical pixels.
  ///
  /// A *limit*, not the box: the box itself shrinks to the longest line — see
  /// [measure]. Text that wrapped at one width and was then outlined at another
  /// is what puts selection handles a thumb's width away from the words.
  double get maxWidth => layer.widthFactor * canvasWidth;

  TextStyle styleFor(BuildContext context) {
    final size = layer.fontSize * canvasWidth;
    final weight = layer.bold ? FontWeight.w700 : FontWeight.w400;
    final slant = layer.italic ? FontStyle.italic : FontStyle.normal;
    // 1.15 rather than the theme's: an invitation headline set on the app's
    // body line-height leaves a visible gap between two lines of display type.
    const lineHeight = 1.15;

    if (!layer.font.isBundled) {
      // `google_fonts` picks the file for the weight and slant asked for, so
      // no `fontVariations` here — those drive a variable axis the fetched
      // static face does not have.
      return GoogleFonts.getFont(
        layer.font.family,
        fontSize: size,
        fontWeight: weight,
        fontStyle: slant,
        color: layer.displayColor,
        height: lineHeight,
      );
    }

    return TextStyle(
      fontFamily: layer.font.family,
      fontSize: size,
      fontWeight: weight,
      fontStyle: slant,
      color: layer.displayColor,
      height: lineHeight,
      // Both bundled families are variable fonts, whose weight axis has to be
      // driven explicitly exactly as AppTypography does — `fontWeight` alone
      // leaves them at their default position and the bold button does nothing.
      fontVariations: [FontVariation('wght', layer.bold ? 700 : 400)],
    );
  }

  /// [styleFor] merged with the ambient [DefaultTextStyle], which is what a
  /// [Text] actually paints with.
  TextStyle resolvedStyle(BuildContext context) =>
      DefaultTextStyle.of(context).style.merge(styleFor(context));

  /// The box the text actually fills.
  ///
  /// Laid out once here and reused by the selection outline, the handles and
  /// the tap target, so all four agree to the pixel. `TextPainter.width` is the
  /// longest line rather than [maxWidth], which is what makes the box hug the
  /// words instead of spanning most of the card.
  ///
  /// [full] returns the wrap box instead — the width the layer is *allowed*,
  /// whether or not the text reaches it. The designer switches to it while the
  /// resize handle is being dragged, because that is the value being edited and
  /// a hugging outline would show no feedback at all until the text happened to
  /// re-wrap.
  Size measure(BuildContext context, {bool full = false}) {
    final painter = TextPainter(
      // The *resolved* style, not the raw one. `Text` merges whatever
      // DefaultTextStyle is in scope into its own, so measuring the unmerged
      // style measures a different paragraph from the one that gets painted —
      // and the box comes out narrower than the glyphs, which re-wraps them.
      text: TextSpan(text: layer.text, style: resolvedStyle(context)),
      textAlign: layer.align.textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    // A pixel of headroom on the hug. Not what fixed "Welcome" breaking into
    // "Welcom / e" — that was measuring the unresolved style above — but the
    // same failure is reachable through subpixel rounding alone: a box of
    // exactly `painter.width` is one float ulp away from not fitting the text
    // it was measured from, and the cost of being wrong is a silently broken
    // headline. Capped at [maxWidth] so the headroom can never widen the wrap.
    return Size(
      full ? maxWidth : math.min(painter.width.ceilToDouble() + 1, maxWidth),
      painter.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      // Fractional, so the layer sits at the same place on a 300-px editor
      // canvas and a 1080-px export. Alignment runs -1..1, the layer stores
      // 0..1, hence the doubling.
      alignment: Alignment(layer.dx * 2 - 1, layer.dy * 2 - 1),
      child: Transform.rotate(
        angle: layer.rotation * 2 * 3.1415926535897932,
        child: SizedBox(
          // The measured width, not [maxWidth] — the same number the handles
          // use, so a selected layer is outlined around its words and sits
          // centred in that outline however short the text is.
          width: measure(context).width,
          child: Text(
            layer.text,
            textAlign: layer.align.textAlign,
            style: styleFor(context),
          ),
        ),
      ),
    );
  }
}
