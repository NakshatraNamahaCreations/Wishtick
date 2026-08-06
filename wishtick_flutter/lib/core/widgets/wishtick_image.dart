import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// Renders a product/cover photo whose source may be a real `https://` URL
/// or, only in dev/fake-backend mode, a local file path (a picked image that
/// was never actually uploaded) — so a dev walkthrough shows the real photo
/// you picked rather than a permanently blank cover.
///
/// Null, empty, or a failed load all fall back to the same themed
/// placeholder, so a missing image never looks like a rendering bug.
class WishtickImage extends StatelessWidget {
  const WishtickImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final value = url;
    Widget image;
    if (value == null || value.isEmpty) {
      image = const _Placeholder();
    } else if (value.startsWith('http://') || value.startsWith('https://')) {
      image = Image.network(
        value,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => const _Placeholder(),
      );
    } else {
      image = Image.file(
        File(value),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => const _Placeholder(),
      );
    }

    final radius = borderRadius;
    return radius == null
        ? image
        : ClipRRect(borderRadius: radius, child: image);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.surfaceAlt,
      child: Center(
        child: Icon(Icons.image_outlined, color: colors.textMuted, size: 32),
      ),
    );
  }
}
