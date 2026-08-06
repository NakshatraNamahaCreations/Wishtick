import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../data/wishlist_repository.dart';
import '../domain/wishlist.dart';

/// Where a share tile sends the link.
enum _ShareTarget {
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

/// Figma `288:780` — share a wishlist.
///
/// Every tile does something real. WhatsApp, Telegram, X and Facebook all
/// publish a share URL that takes a link, so those open directly. Instagram
/// and Snapchat do not — link sharing needs their SDKs — so they open the
/// system sheet, which lists them as targets anyway.
class ShareWishlistScreen extends ConsumerStatefulWidget {
  const ShareWishlistScreen({required this.wishlist, super.key});

  final Wishlist wishlist;

  @override
  ConsumerState<ShareWishlistScreen> createState() =>
      _ShareWishlistScreenState();
}

class _ShareWishlistScreenState extends ConsumerState<ShareWishlistScreen> {
  ShareInfo? _share;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadShareLink());
  }

  /// A wishlist may never have been shared, so the link is fetched (and minted
  /// if need be) by calling share with nothing to change.
  Future<void> _loadShareLink() async {
    try {
      final share =
          widget.wishlist.share ??
          await ref
              .read(wishlistRepositoryProvider)
              .configureShare(widget.wishlist.id);
      if (!mounted) return;
      setState(() {
        _share = share;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String get _message =>
      'Take a look at my wishlist "${widget.wishlist.title}" on Wishtick';

  Future<void> _onTargetTapped(_ShareTarget target) async {
    final url = _share?.url;
    if (url == null) return;

    final encodedUrl = Uri.encodeComponent(url);
    final encodedMessage = Uri.encodeComponent('$_message\n$url');

    switch (target) {
      case _ShareTarget.copyLink:
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard')),
        );

      case _ShareTarget.whatsapp:
        await _open('https://wa.me/?text=$encodedMessage');
      case _ShareTarget.telegram:
        await _open(
          'https://t.me/share/url?url=$encodedUrl'
          '&text=${Uri.encodeComponent(_message)}',
        );
      case _ShareTarget.twitter:
        await _open(
          'https://twitter.com/intent/tweet?url=$encodedUrl'
          '&text=${Uri.encodeComponent(_message)}',
        );
      case _ShareTarget.facebook:
        await _open('https://www.facebook.com/sharer/sharer.php?u=$encodedUrl');

      case _ShareTarget.instagram:
      case _ShareTarget.snapchat:
      case _ShareTarget.moreApps:
        await SharePlus.instance.share(
          ShareParams(text: '$_message\n$url', subject: widget.wishlist.title),
        );
    }
  }

  Future<void> _open(String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (launched || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open that app')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Share Wishlist',
              style: context.text.headlineSmall?.copyWith(
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Share with your friends & family',
              style: context.text.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _WishlistCard(wishlist: widget.wishlist),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Share Via',
              style: context.text.titleMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_error != null)
              WishtickErrorText(_error!)
            else
              _ShareTargetGrid(enabled: !_loading, onTap: _onTargetTapped),
          ],
        ),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({required this.wishlist});

  final Wishlist wishlist;

  static String _visibilityLabel(WishlistVisibility v) => switch (v) {
    WishlistVisibility.public => 'Public',
    WishlistVisibility.private => 'Private',
    WishlistVisibility.eventOnly => 'Event',
    WishlistVisibility.inviteOnly => 'Invite only',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final itemWord = wishlist.itemCount == 1 ? 'item' : 'items';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: WishtickImage(
                url: wishlist.coverUrl,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    wishlist.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${_visibilityLabel(wishlist.visibility)} · '
                    '${wishlist.itemCount} $itemWord',
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareTargetGrid extends StatelessWidget {
  const _ShareTargetGrid({required this.enabled, required this.onTap});

  final bool enabled;
  final ValueChanged<_ShareTarget> onTap;

  /// Brand marks are not bundled, so each tile uses a themed icon rather than
  /// an approximation of someone's logo.
  static const _targets = <(_ShareTarget, IconData, String)>[
    (_ShareTarget.copyLink, Icons.link, 'Copy link'),
    (_ShareTarget.whatsapp, Icons.chat_bubble_outline, 'Whatsapp'),
    (_ShareTarget.instagram, Icons.camera_alt_outlined, 'Instagram'),
    (_ShareTarget.facebook, Icons.public, 'Facebook'),
    (_ShareTarget.snapchat, Icons.photo_camera_outlined, 'Snapchat'),
    (_ShareTarget.telegram, Icons.send_outlined, 'Telegram'),
    (_ShareTarget.twitter, Icons.alternate_email, 'Twitter'),
    (_ShareTarget.moreApps, Icons.more_horiz, 'More Apps'),
  ];

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
          childAspectRatio: 0.85,
          children: [
            for (final (target, icon, label) in _targets)
              _ShareTile(
                icon: icon,
                label: label,
                onTap: enabled ? () => onTap(target) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _ShareTile extends StatelessWidget {
  const _ShareTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  static const _size = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: colors.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.primary, size: AppSizes.iconMd),
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
