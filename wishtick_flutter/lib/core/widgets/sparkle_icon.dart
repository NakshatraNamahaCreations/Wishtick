import 'package:flutter/material.dart';

/// The Wishtick sparkle, drawn from the brand asset rather than Material's
/// `Icons.auto_awesome`.
///
/// The asset is a monochrome PNG carrying only an alpha channel, so it tints
/// and scales exactly like a font icon. [ImageIcon] resolves both size and
/// colour from the ambient [IconTheme] when they are not passed, which is what
/// lets this sit inside an icon map alongside real [Icon]s and be sized by
/// whatever renders it.
///
/// Use this anywhere the sparkle appears — `Icons.auto_awesome` is Material's
/// glyph, not ours, and the two do not match.
class SparkleIcon extends StatelessWidget {
  const SparkleIcon({super.key, this.size, this.color});

  static const asset = 'assets/icons/daimond.png';

  /// Falls back to the ambient [IconTheme], as [Icon] does.
  final double? size;

  /// Falls back to the ambient [IconTheme], as [Icon] does.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ImageIcon(const AssetImage(asset), size: size, color: color);
  }
}
