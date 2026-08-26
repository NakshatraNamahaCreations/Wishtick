import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../wishmates/presentation/widgets/quick_share_sheet.dart';
import '../domain/wishlist.dart';
import '../domain/wishlist_participant.dart';
import 'manage_access_controller.dart';

/// Who can open this wishlist — and the only way to let anyone in.
///
/// No Figma frame exists for this screen; it is built to close a real hole.
/// A `private` wishlist admits participants and nobody else — its share link
/// grants nothing — so without this page the "Only invited people can view"
/// setting described a state the app could not reach.
///
/// Access is granted by picking WishMates. Anybody else is reached with the
/// list's own share link, which makes them an account before it makes them a
/// participant — so there is no address to type, none to mistype, and no
/// invite sitting unclaimed waiting for a signup that may never come.
class ManageAccessScreen extends ConsumerStatefulWidget {
  const ManageAccessScreen({required this.wishlist, super.key});

  final Wishlist wishlist;

  @override
  ConsumerState<ManageAccessScreen> createState() => _ManageAccessScreenState();
}

class _ManageAccessScreenState extends ConsumerState<ManageAccessScreen> {
  /// Whether the next invite may also join the wishlist's chat. Only offered
  /// when the list has chat at all — a role that unlocks nothing is noise.
  bool _canChat = false;

  String get _id => widget.wishlist.id;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(manageAccessProvider(_id).notifier).ensureLoaded(),
    );
  }

  Future<void> _invite() async {
    await showQuickShareSheet(
      context,
      WishlistShareTarget(
        wishlistId: _id,
        title: widget.wishlist.title,
        slug: widget.wishlist.share?.slug,
        // `event_only` and `private` both admit nobody by link — only the
        // people explicitly given access — so neither offers one.
        isPublic:
            widget.wishlist.visibility == WishlistVisibility.public ||
            widget.wishlist.visibility == WishlistVisibility.inviteOnly,
        role: _canChat ? ParticipantRole.contributor : ParticipantRole.viewer,
      ),
    );
    if (!mounted) return;
    // The sheet adds people through the repository directly, so this screen's
    // own list is stale by exactly the people it just added.
    await ref.read(manageAccessProvider(_id).notifier).refresh();
  }

  Future<void> _confirmRemove(WishlistParticipant person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${person.displayName}?'),
        content: const Text(
          'They lose access to this wishlist straight away, including its '
          'chat. You can invite them again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Remove',
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(manageAccessProvider(_id).notifier).revoke(person.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(manageAccessProvider(_id));
    final people = state.participants;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Who can see this')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _VisibilityCard(visibility: widget.wishlist.visibility),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Invite someone',
              style: context.text.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pick from your WishMates. They will see this list the next time '
              'they open Wishtick.',
              style: context.text.bodySmall?.copyWith(
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // The toggle sits ABOVE the button, not below it: it changes what
            // the button is about to grant, and a switch read after the sheet
            // has already opened is a switch read too late.
            if (widget.wishlist.chatEnabled) ...[
              _ChatToggle(
                value: _canChat,
                onChanged: (next) => setState(() => _canChat = next),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _InviteButton(
              busy: state.busy,
              onPressed: () => unawaited(_invite()),
            ),
            if (state.error case final message?) ...[
              const SizedBox(height: AppSpacing.md),
              WishtickErrorText(message),
            ],

            const SizedBox(height: AppSpacing.xl),
            Text(
              'People with access',
              style: context.text.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (people == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (people.isEmpty)
              _EmptyAccessList(visibility: widget.wishlist.visibility)
            else
              for (final person in people) ...[
                _PersonRow(
                  person: person,
                  onRemove: state.busy
                      ? null
                      : () => unawaited(_confirmRemove(person)),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}

/// What the current setting means, stated plainly at the top — including the
/// part people get wrong, which is whether the link works.
class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({required this.visibility});

  final WishlistVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final linkWorks = visibility.linkGrantsAccess;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            linkWorks ? Icons.link : Icons.lock_outline,
            size: AppSizes.iconMd,
            color: colors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This list is ${visibility.label}',
                  style: context.text.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  visibility.summary,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (!linkWorks) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sharing the link is not enough — anyone opening it will '
                    'be turned away unless they are on the list below.',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the WishMate picker. Full-width, because it is the only action in
/// its section — the old email row had to share the line with its field.
class _InviteButton extends StatelessWidget {
  const _InviteButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.inputHeight,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? SizedBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(context.colors.onPrimary),
                ),
              )
            : const Icon(Icons.person_add_alt_1, size: AppSizes.iconMd),
        label: const Text('Choose WishMates'),
      ),
    );
  }
}

/// Grants the chat role instead of the plain viewer one.
class _ChatToggle extends StatelessWidget {
  const _ChatToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Let them join the chat',
        style: context.text.bodyMedium?.copyWith(color: colors.textPrimary),
      ),
      subtitle: Text(
        'They can view and gift either way.',
        style: context.text.bodySmall?.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onRemove});

  final WishlistParticipant person;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = person.subtitle;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: AppSizes.avatarSm / 2,
            backgroundColor: colors.primarySubtle,
            child: Text(
              person.displayName.characters.first.toUpperCase(),
              style: context.text.titleSmall?.copyWith(
                color: context.headlineBrandColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        person.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (person.isPending) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const _PendingChip(),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle ?? person.role.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close),
            iconSize: AppSizes.iconMd,
            color: colors.textMuted,
            tooltip: 'Remove ${person.displayName}',
          ),
        ],
      ),
    );
  }
}

/// Marks an email invite nobody has claimed yet.
class _PendingChip extends StatelessWidget {
  const _PendingChip();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.warningSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Invited',
        style: context.text.labelSmall?.copyWith(color: colors.onWarningSubtle),
      ),
    );
  }
}

class _EmptyAccessList extends StatelessWidget {
  const _EmptyAccessList({required this.visibility});

  final WishlistVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_add_alt,
            size: AppSizes.iconLg,
            color: colors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            visibility.linkGrantsAccess
                ? 'Nobody has been invited yet.'
                : 'Only you can see this list.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
