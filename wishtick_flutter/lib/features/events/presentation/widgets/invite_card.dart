import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/hex_color.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/invite_template.dart';

/// The invitation as the guest will receive it (`263:1014`).
///
/// Drawn from the template's own palette, never the app's: an invitation looks
/// the same to everyone, so it must not flip with the viewer's theme. The only
/// app tokens used are fallbacks for an unparseable colour.
///
/// Deliberately **not** the `imageUrl` the preview endpoint also returns. That
/// raster is 1200×630 — the Open Graph size WhatsApp crops to when a share
/// link unfurls — and this frame is a portrait card. Showing the landscape
/// raster here means either letterboxing it or cropping the headline in half;
/// the palette and the resolved copy draw the real thing at the real shape.
class InviteCard extends StatelessWidget {
  const InviteCard({required this.preview, super.key});

  final InvitePreview preview;

  /// The frame draws the card at 344×432 in a 393-wide screen — a hair over
  /// 4:5. Keeping the ratio rather than the pixels lets it scale with the
  /// device.
  static const aspectRatio = 344 / 432;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = preview.palette;
    final background = parseHexColor(
      palette.background,
      fallback: colors.primaryDeep,
    );
    final accent = parseHexColor(palette.accent, fallback: colors.accent);
    final ink = parseHexColor(palette.text, fallback: colors.textOnDark);
    final muted = parseHexColor(palette.muted, fallback: colors.textOnDark);
    final content = preview.resolved;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ColoredBox(
          color: background,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'YOU ARE INVITED TO\nJOIN US FOR',
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(
                    color: muted,
                    letterSpacing: 1.4,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Flexible(
                  child: Text(
                    content.headline,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.headlineSmall?.copyWith(
                      color: ink,
                      fontStyle: FontStyle.italic,
                      height: 1.15,
                    ),
                  ),
                ),
                if (content.subtitle != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    content.subtitle!.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
                if (content.hostLine != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    content.hostLine!.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  content.dateLine,
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                if (content.venue != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    content.venue!.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
                if (content.note != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Flexible(
                    child: Text(
                      content.note!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
