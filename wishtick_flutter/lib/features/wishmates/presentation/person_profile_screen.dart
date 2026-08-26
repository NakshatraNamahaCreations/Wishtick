import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/wishmate.dart';
import 'widgets/people_you_may_know.dart';
import 'widgets/person_avatar.dart';
import 'wishmate_actions.dart';
import 'wishmates_providers.dart';

/// Somebody's profile — `4177:217` when you are not connected, `4177:267` when
/// you are.
///
/// One screen, because the two frames are the same layout with one button
/// swapped and one section added. Which it draws is decided by the
/// relationship the *server* reports, never by what the caller assumed: a
/// request accepted on another device has to change this screen, and a stale
/// "Add WishMate" that silently does nothing is worse than a slow one.
class PersonProfileScreen extends ConsumerWidget {
  const PersonProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(personProfileProvider(userId));

    return Scaffold(
      backgroundColor: colors.background,
      // See the note in `wishmates_list_screen.dart` on this ordering.
      body: switch (profile) {
        AsyncValue(hasError: true, hasValue: false) => _ProfileError(
          onRetry: () => ref.invalidate(personProfileProvider(userId)),
        ),
        AsyncValue(hasValue: false) => const Center(
          child: CircularProgressIndicator(),
        ),
        AsyncValue(:final value?) => _Body(profile: value),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.profile});

  final WishmateProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => invalidateWishmateGraph(ref),
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          _Hero(profile: profile),
          const SizedBox(height: AppSpacing.xxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: _AboutCard(profile: profile),
          ),
          // Only ever populated for someone you share an upcoming event with,
          // so the section is absent rather than empty for almost everyone —
          // which is exactly how `4177:217` (no activity) differs from
          // `4177:267` (one card).
          if (profile.recentActivity.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: context.text.titleMedium?.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final activity in profile.recentActivity) ...[
                    _ActivityCard(activity: activity),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          PeopleYouMayKnowCards(
            // `4177:217` calls the rail "Find WishMates" and `4177:267` calls
            // it "People You May Know" — the same rail, worded for whether you
            // have just arrived at a stranger or are already connected.
            title: profile.relationship == WishmateRelationship.wishmates
                ? 'People You May Know'
                : 'Find WishMates',
            onOpen: (person) =>
                unawaited(context.push(AppRoutes.person(person.userId))),
          ),
        ],
      ),
    );
  }
}

/// The plum hero: avatar, name, handle, mutuals, and the two action pills.
class _Hero extends ConsumerWidget {
  /// The disc inside the halo, measured off `4177:267` at x 146→246.
  /// Larger than [AppSizes.avatarLg], which is the 96 used elsewhere.
  static const _avatarDiameter = 100.0;

  const _Hero({required this.profile});

  final WishmateProfile profile;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(wishmateActionsProvider)
        .request(profile.person.userId);
    if (!context.mounted) return;
    if (reportWishmateResult(context, result) &&
        result.relationship == WishmateRelationship.wishmates) {
      // They had already asked, so asking back connected the two of you on the
      // spot. Say so — the button quietly becoming "Remove WishMate" would
      // look like a bug.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You and ${profile.person.name} are now WishMates.'),
        ),
      );
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove WishMate?'),
        content: Text(
          'You and ${profile.person.name} will no longer be WishMates, and '
          'neither of you will be able to send new messages. Your '
          'conversation is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref
        .read(wishmateActionsProvider)
        .remove(profile.person.userId);
    if (context.mounted) reportWishmateResult(context, result);
  }

  /// The share glyph on `4177:217`.
  ///
  /// Text only, and deliberately so: there is no `/u/` link yet. The claimed
  /// deep-link prefixes are `/i/ /e/ /w/ /m/`, none of which resolves to a
  /// person, and inventing a URL here would put an address into somebody's
  /// WhatsApp that opens nothing. The handle is the part that works — it is
  /// what People Search matches on.
  Future<void> _share(BuildContext context) async {
    final person = profile.person;
    final handle = person.username == null ? person.name : person.handle;
    await SharePlus.instance.share(
      ShareParams(text: 'Find $handle on Wishtick'),
    );
  }

  /// The overflow beside it.
  ///
  /// Only actions that already exist end up here. A menu is the easiest place
  /// to promise something the app cannot do — "Block", "Report" — and an
  /// entry that opens a snackbar saying "coming soon" is worse than no entry.
  Future<void> _showMore(BuildContext context, WidgetRef ref) async {
    final person = profile.person;
    final connected = profile.relationship == WishmateRelationship.wishmates;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (person.username != null)
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: const Text('Copy handle'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(ClipboardData(text: person.handle));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Handle copied')),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share this profile'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_share(context));
              },
            ),
            if (connected)
              ListTile(
                leading: const Icon(Icons.person_remove_alt_1_outlined),
                title: const Text('Remove WishMate'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_remove(context, ref));
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Where "Requested" sends you.
  ///
  /// A profile reports a *relationship*, not the WishLink row behind it, so
  /// this screen has no `linkId` to withdraw. Rather than fetch the Sent list
  /// just to find one, the tab that already lists them is offered — which is
  /// also where someone would look for "what have I asked for?".
  void _pointAtSentTab(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Waiting for an answer.'),
        action: SnackBarAction(
          label: 'Sent',
          onPressed: () => unawaited(context.push(AppRoutes.wishlinks)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final person = profile.person;

    return Container(
      width: double.infinity,
      // Not `gradients.header`: that is the violet-leaning ink → plum of
      // Home's masthead, and it reads blue at the status bar. Sampling
      // `4177:217` down its left edge gives plumShadow → plumRich → plumMuted
      // to the pixel — the same three stops this token already holds.
      decoration: BoxDecoration(gradient: context.gradients.eventMasthead),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        bottom: AppSpacing.xl,
      ),
      child: Column(
        children: [
          Row(
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
              const Spacer(),
              _HeroAction(
                icon: Icons.ios_share,
                tooltip: 'Share this profile',
                // The frame gives this one a filled disc and leaves the
                // overflow bare, which is what marks it as the primary of the
                // pair. Sampled at 22% white over the plum.
                fill: colors.textOnDark.withValues(alpha: 0.22),
                onPressed: () => unawaited(_share(context)),
              ),
              _HeroAction(
                icon: Icons.more_vert,
                tooltip: 'More',
                onPressed: () => unawaited(_showMore(context, ref)),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          PersonAvatar(
            person: person,
            // 100 inside a 10-px halo, measured off `4177:267` at x 136→256
            // (ring) and 146→246 (disc).
            diameter: _avatarDiameter,
            ringColor: colors.textOnDark.withValues(alpha: 0.13),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            person.name,
            style: context.text.titleLarge?.copyWith(
              color: colors.textOnDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            person.handle,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textOnDark.withValues(alpha: 0.8),
            ),
          ),
          if (person.mutualCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            _MutualStack(profile: profile),
          ],
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Row(
              children: [
                Expanded(child: _relationshipButton(context, ref)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _HeroButton(
                    label: 'Message',
                    // A frosted fill sampled at 18% white over the plum — the
                    // secondary of the pair on both frames.
                    fill: colors.textOnDark.withValues(alpha: 0.18),
                    // Direct messages are gated on an accepted link, so this is
                    // inert until you are connected. Offered-but-disabled
                    // rather than hidden: the frame draws it in both states.
                    onPressed: profile.canMessage
                        ? () => unawaited(
                            context.push(AppRoutes.directChat(person.userId)),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _relationshipButton(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return switch (profile.relationship) {
      WishmateRelationship.wishmates => _HeroButton(
        label: 'Remove WishMate',
        outlined: true,
        onPressed: () => unawaited(_remove(context, ref)),
      ),
      WishmateRelationship.requestSent => _HeroButton(
        label: 'Requested',
        outlined: true,
        onPressed: () => _pointAtSentTab(context),
      ),
      // They asked first, so this single tap accepts — which is what the
      // server does with a request sent back the other way.
      WishmateRelationship.requestReceived => _HeroButton(
        label: 'Accept WishLink',
        fill: colors.cta,
        onPressed: () => unawaited(_add(context, ref)),
      ),
      WishmateRelationship.self => _HeroButton(
        label: 'This is you',
        outlined: true,
        onPressed: null,
      ),
      WishmateRelationship.none => _HeroButton(
        label: 'Add WishMate',
        outlined: true,
        onPressed: () => unawaited(_add(context, ref)),
      ),
    };
  }
}

/// The overlapping avatars beside "4 Mutual Friends".
class _MutualStack extends StatelessWidget {
  const _MutualStack({required this.profile});

  final WishmateProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final faces = profile.mutuals.take(4).toList();
    const size = AppSizes.avatarSm;
    const overlap = 10.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (faces.isNotEmpty)
          SizedBox(
            width: size + (faces.length - 1) * (size - overlap),
            height: size,
            child: Stack(
              children: [
                for (var i = 0; i < faces.length; i++)
                  Positioned(
                    left: i * (size - overlap),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.primaryDeep, width: 2),
                      ),
                      child: PersonAvatar(
                        person: faces[i],
                        diameter: size,
                        // Six presence dots in a 4-avatar stack is noise.
                        showPresence: false,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          profile.person.mutualCount == 1
              ? '1 Mutual Friend'
              : '${profile.person.mutualCount} Mutual Friends',
          style: context.text.bodyMedium?.copyWith(color: colors.textOnDark),
        ),
      ],
    );
  }
}

/// One of the two pills on the plum hero.
class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.onPressed,
    this.fill,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? fill;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
    const height = 44.0;

    if (outlined) {
      return SizedBox(
        height: height,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textOnDark,
            disabledForegroundColor: colors.textOnDark.withValues(alpha: 0.5),
            side: BorderSide(color: colors.textOnDark),
            shape: shape,
            padding: EdgeInsets.zero,
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: fill ?? colors.cta,
          foregroundColor: colors.textOnDark,
          disabledBackgroundColor: (fill ?? colors.cta).withValues(alpha: 0.4),
          disabledForegroundColor: colors.textOnDark.withValues(alpha: 0.5),
          shape: shape,
          padding: EdgeInsets.zero,
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// "About This Profile" — location and join date, each a row of the same card.
class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.profile});

  final WishmateProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final location = profile.location;
    final joined = DateFormat('d MMMM y').format(profile.joinedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About This Profile',
          style: context.text.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              // Only when they filled it in — an empty "location" row would
              // say something false about a person who chose not to say.
              if (location != null) ...[
                _AboutRow(icon: Icons.place_outlined, text: location),
                Divider(height: 1, color: colors.border),
              ],
              _AboutRow(
                icon: Icons.calendar_today_outlined,
                text: 'Joined Wishtick on $joined',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconMd, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One "Recent Activity" card: an event you are both going to.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final WishmateActivity activity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final when = DateFormat('d MMMM y').format(activity.startsAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.primarySubtle,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              activity.attendingLabel(),
              style: context.text.labelSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            activity.title,
            style: context.text.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: AppSizes.iconSm,
                color: colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  [when, ?activity.venue].join(' | '),
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Could not load this profile.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

/// One of the two controls in the hero's top-right corner (`4177:217`).
///
/// A 32-px disc, filled for share and bare for the overflow, inside a tap
/// target big enough to hit. The two are 32 apart on the frame, which is
/// narrower than [AppSizes.minTapTarget] allows for a default [IconButton] —
/// hence the explicit constraints rather than stock padding.
class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.fill,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? fill;

  static const _disc = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: _disc,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Container(
            width: _disc,
            height: _disc,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
            child: Icon(icon, size: AppSizes.iconMd, color: colors.textOnDark),
          ),
        ),
      ),
    );
  }
}
