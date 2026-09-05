import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/share_via_grid.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_image.dart';
import '../data/wishlist_repository.dart';
import '../domain/wishlist.dart';

/// Figma `288:780` — share a wishlist.
///
/// The grid and where each tile sends the link are [ShareViaGrid] and
/// [shareTo], shared with the event invitation's share screen.
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
    // No point minting a slug for a list whose link admits nobody — the
    // screen shows the invite route instead, and the request would only be a
    // write nothing reads.
    if (widget.wishlist.visibility.linkGrantsAccess) {
      unawaited(_loadShareLink());
    } else {
      _loading = false;
    }
  }

  void _openAccess() => context.push(
    AppRoutes.wishlistAccess(widget.wishlist.id),
    extra: widget.wishlist,
  );

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

  Future<void> _onTargetTapped(ShareTarget target) async {
    final url = _share?.url;
    if (url == null) return;
    await shareTo(
      context,
      target,
      url: url,
      message: _message,
      subject: widget.wishlist.title,
    );
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
            // A link is worthless on a list the access policy will not admit a
            // link holder to. Saying so — and offering the thing that does
            // work — beats handing over a URL that quietly 403s for everyone
            // the owner sends it to.
            if (!widget.wishlist.visibility.linkGrantsAccess)
              _LinkWontWorkNotice(
                wishlist: widget.wishlist,
                onInvite: _openAccess,
              )
            else ...[
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
                ShareViaGrid(enabled: !_loading, onTap: _onTargetTapped),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown instead of the share grid when the list's visibility means a link
/// holder is refused — `private` and `event_only`.
///
/// This screen used to hand over a URL regardless, which is the worst possible
/// answer: the owner believes they have shared it, and the friend hits a wall
/// with no explanation on either side.
class _LinkWontWorkNotice extends StatelessWidget {
  const _LinkWontWorkNotice({required this.wishlist, required this.onInvite});

  final Wishlist wishlist;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEventOnly = wishlist.visibility == WishlistVisibility.eventOnly;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.warningSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: AppSizes.iconMd,
                color: colors.onWarningSubtle,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'A link won’t open this list',
                  style: context.text.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isEventOnly
                ? 'This wishlist is Event only, so it opens for people invited '
                      'to the event — and for anyone you add by name. Sending '
                      'the link to someone else will not let them in.'
                : 'This wishlist is Private, so only the people you invite can '
                      'open it. Sending the link to someone else will not let '
                      'them in.',
            style: context.text.bodyMedium?.copyWith(
              color: colors.textPrimary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.person_add_alt, size: AppSizes.iconMd),
              label: const Text('Invite people'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Want a link anyone can open? Change the wishlist’s privacy to '
            'Public, or to Invite only for an unlisted link.',
            style: context.text.bodySmall?.copyWith(
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({required this.wishlist});

  final Wishlist wishlist;

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
                    '${wishlist.visibility.label} · '
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
