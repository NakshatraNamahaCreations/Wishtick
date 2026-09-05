import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/theme_extensions.dart';

/// Where a share tile sends the link.
enum ShareTarget {
  /// Straight to the clipboard.
  copyLink,

  /// Opens the app (or its web fallback) with the link pre-filled.
  whatsapp,
  telegram,
  twitter,
  facebook,

  /// No public URL scheme accepts an arbitrary link, so these hand off to the
  /// OS share sheet rather than pretending to deep-link.
  instagram,
  snapchat,
  moreApps,
}

/// Sends [url] where [target] points.
///
/// Every target does something real. WhatsApp, Telegram, X and Facebook all
/// publish a share URL that takes a link, so those open directly. Instagram
/// and Snapchat do not — link sharing needs their SDKs — so they open the
/// system sheet, which lists them as targets anyway. [message] travels with
/// the link; [subject] is the title the sheet shows where it shows one.
///
/// The messenger is looked up before the first await, so the confirmation can
/// still be shown after the launch even if the caller has gone.
Future<void> shareTo(
  BuildContext context,
  ShareTarget target, {
  required String url,
  required String message,
  String? subject,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final encodedUrl = Uri.encodeComponent(url);
  final encodedMessage = Uri.encodeComponent('$message\n$url');
  final encodedText = Uri.encodeComponent(message);

  switch (target) {
    case ShareTarget.copyLink:
      await Clipboard.setData(ClipboardData(text: url));
      messenger?.showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );

    case ShareTarget.whatsapp:
      await _open(messenger, 'https://wa.me/?text=$encodedMessage');
    case ShareTarget.telegram:
      await _open(
        messenger,
        'https://t.me/share/url?url=$encodedUrl&text=$encodedText',
      );
    case ShareTarget.twitter:
      await _open(
        messenger,
        'https://twitter.com/intent/tweet?url=$encodedUrl&text=$encodedText',
      );
    case ShareTarget.facebook:
      await _open(
        messenger,
        'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl',
      );

    case ShareTarget.instagram:
    case ShareTarget.snapchat:
    case ShareTarget.moreApps:
      await SharePlus.instance.share(
        ShareParams(text: '$message\n$url', subject: subject),
      );
  }
}

Future<void> _open(ScaffoldMessengerState? messenger, String url) async {
  final launched = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (launched) return;
  messenger?.showSnackBar(
    const SnackBar(content: Text('Could not open that app')),
  );
}

/// How one tile's mark is drawn: the fill behind the glyph, the glyph's
/// colour, and whether the fill is a disc or the rounded square Instagram
/// and Snapchat use for their own icons.
class _Mark {
  const _Mark({
    required this.ink,
    this.fill,
    this.gradient,
    this.square = false,
  }) : assert(fill != null || gradient != null, 'a mark needs a fill');

  final Color? fill;
  final List<Color>? gradient;
  final Color ink;
  final bool square;
}

/// The eight-tile "Share Via" grid (`288:780`), shared by everything that
/// hands out a link — one grid rather than one per feature, so the targets
/// and their order never drift between a wishlist and an invitation.
///
/// Each tile carries the service's own mark, from Font Awesome's brand set,
/// on its own colour — WhatsApp's green, Telegram's blue — as the export
/// draws them. A generic chat bubble in brand plum would say "something" where
/// the design says "WhatsApp".
class ShareViaGrid extends StatelessWidget {
  const ShareViaGrid({required this.enabled, required this.onTap, super.key});

  final bool enabled;
  final ValueChanged<ShareTarget> onTap;

  /// Telegram's logo is a white paper plane on its blue — so on a blue disc
  /// the plane *is* the mark, where the set's own `telegram` glyph (a disc
  /// with a plane inside) would draw a circle inside a circle.
  static const _targets = <(ShareTarget, FaIconData, String)>[
    (ShareTarget.copyLink, FontAwesomeIcons.link, 'Copy link'),
    (ShareTarget.whatsapp, FontAwesomeIcons.whatsapp, 'Whatsapp'),
    (ShareTarget.instagram, FontAwesomeIcons.instagram, 'Instagram'),
    (ShareTarget.facebook, FontAwesomeIcons.facebookF, 'Facebook'),
    (ShareTarget.snapchat, FontAwesomeIcons.snapchat, 'Snapchat'),
    (ShareTarget.telegram, FontAwesomeIcons.solidPaperPlane, 'Telegram'),
    (ShareTarget.twitter, FontAwesomeIcons.xTwitter, 'Twitter'),
    (ShareTarget.moreApps, FontAwesomeIcons.ellipsis, 'More Apps'),
  ];

  static _Mark _markFor(ShareTarget target, ShareBrandColors brand) =>
      switch (target) {
        ShareTarget.copyLink => _Mark(fill: brand.link, ink: brand.onBrand),
        ShareTarget.whatsapp => _Mark(fill: brand.whatsApp, ink: brand.onBrand),
        ShareTarget.instagram => _Mark(
          gradient: brand.instagram,
          ink: brand.onBrand,
          square: true,
        ),
        ShareTarget.facebook => _Mark(fill: brand.facebook, ink: brand.onBrand),
        ShareTarget.snapchat => _Mark(
          fill: brand.snapchat,
          ink: brand.onSnapchat,
          square: true,
        ),
        ShareTarget.telegram => _Mark(fill: brand.telegram, ink: brand.onBrand),
        ShareTarget.twitter => _Mark(fill: brand.x, ink: brand.onBrand),
        ShareTarget.moreApps => _Mark(fill: brand.moreFill, ink: brand.moreInk),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.lg,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.1,
          children: [
            for (final (target, icon, label) in _targets)
              _ShareTile(
                target: target,
                icon: icon,
                label: label,
                mark: _markFor(target, colors.shareBrand),
                onTap: enabled ? () => onTap(target) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _ShareTile extends StatelessWidget {
  const _ShareTile({
    required this.target,
    required this.icon,
    required this.label,
    required this.mark,
    this.onTap,
  });

  final ShareTarget target;
  final FaIconData icon;
  final String label;
  final _Mark mark;
  final VoidCallback? onTap;

  /// 32 px on the export — measured across WhatsApp's disc.
  static const _size = 32.0;
  static const _glyph = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gradient = mark.gradient;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: ValueKey('share-mark-${target.name}'),
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: gradient == null ? mark.fill : null,
                gradient: gradient == null
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                shape: mark.square ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: mark.square
                    ? BorderRadius.circular(AppRadius.sm)
                    : null,
              ),
              alignment: Alignment.center,
              child: FaIcon(icon, size: _glyph, color: mark.ink),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
