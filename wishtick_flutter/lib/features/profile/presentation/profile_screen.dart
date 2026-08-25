import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/me.dart';
import 'profile_providers.dart';
import 'widgets/profile_avatar.dart';

/// "My Profile" (`64:158`) — the fourth tab and the hub for everything
/// personal.
///
/// The design's "Refunds & Payouts" row is deliberately absent: Wishtick takes
/// no payment (every purchase happens at the merchant), so there is nothing to
/// refund and no payout to show. A row that opened an empty screen would
/// promise a feature the product does not have.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to see your wishlists and gifts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionProvider.notifier).signOut();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // Two steps on purpose: this is the one irreversible action in the app,
    // and a single tap next to "Log out" is too close to a mistake.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This removes your profile, wishlists, events and memories for good. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete for good'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(sessionProvider.notifier).deleteAccount();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final me = ref.watch(meProvider);
    final counts = ref.watch(profileCountsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(meProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              const _Header(),
              _Identity(me: me.value),
              const SizedBox(height: AppSpacing.xl),
              _CountsRow(counts: counts),
              const SizedBox(height: AppSpacing.xl),
              _Card(
                title: 'YOUR INFORMATION',
                rows: [
                  _Row(
                    icon: Icons.person_outline,
                    label: 'Edit Profile',
                    onTap: () => context.push<void>(AppRoutes.editProfile),
                  ),
                  // The chat list's only entry point. A 1:1 thread is opened
                  // from the person it is with (`4177:267`'s Message button),
                  // but the *list* of them has to hang off something, and no
                  // frame in the WishMates set says what.
                  _Row(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    onTap: () => context.push<void>(AppRoutes.chats),
                  ),
                  _Row(
                    icon: Icons.people_outline,
                    label: 'WishMates',
                    onTap: () => context.push<void>(AppRoutes.wishmates),
                  ),
                  _Row(
                    icon: Icons.favorite_border,
                    iconColor: colors.accent,
                    label: 'My Wishlist',
                    onTap: () => context.go(AppRoutes.wishlist),
                  ),
                  _Row(
                    icon: Icons.card_giftcard,
                    iconColor: colors.danger,
                    label: 'Gifts on hold by me',
                    onTap: () => context.push<void>(AppRoutes.giftsOnHold),
                  ),
                  _Row(
                    icon: Icons.redeem,
                    iconColor: colors.success,
                    label: 'Gifts Received',
                    onTap: () => context.push<void>(AppRoutes.giftsReceived),
                  ),
                  _Row(
                    icon: Icons.card_giftcard_outlined,
                    iconColor: colors.info,
                    label: 'Gifts Given',
                    onTap: () => context.push<void>(AppRoutes.giftsGiven),
                  ),
                  _Row(
                    icon: Icons.celebration_outlined,
                    label: 'My Events & Invites',
                    onTap: () => context.push<void>(AppRoutes.myEvents),
                  ),
                  _Row(
                    icon: Icons.photo_library_outlined,
                    label: 'My Memories',
                    onTap: () => context.go(AppRoutes.memories),
                  ),
                  _Row(
                    icon: Icons.location_on_outlined,
                    label: 'Address Book',
                    onTap: () => context.push<void>(AppRoutes.addressBook),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Card(
                rows: [
                  _Row(
                    icon: Icons.headset_mic_outlined,
                    label: 'Help Centre',
                    onTap: () => context.push<void>(AppRoutes.helpCentre),
                  ),
                  _Row(
                    icon: Icons.settings_outlined,
                    label: 'Notification Settings',
                    onTap: () =>
                        context.push<void>(AppRoutes.notificationSettings),
                  ),
                  _Row(
                    icon: Icons.info_outline,
                    label: 'About Us',
                    onTap: () => context.push<void>(AppRoutes.aboutUs),
                  ),
                  _Row(
                    icon: Icons.description_outlined,
                    label: 'Terms of Use',
                    onTap: () => context.push<void>(AppRoutes.terms),
                  ),
                  _Row(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => context.push<void>(AppRoutes.privacyPolicy),
                  ),
                ],
                footer: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      _DangerButton(
                        label: 'LOGOUT',
                        onTap: () => unawaited(_confirmLogout(context, ref)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _DangerButton(
                        label: 'DELETE ACCOUNT',
                        emphasised: true,
                        onTap: () => unawaited(_confirmDelete(context, ref)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back chevron, title, and the "Help" pill on the right.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      // A Stack, not a Row: the frame balances the Help pill against a back
      // chevron, and a tab root has nothing to pop to. Centring the title in
      // the *remaining* space instead pushed it visibly left of centre on the
      // device, so the title is laid out across the full width and the pill
      // floats over its right end.
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'My Profile',
            textAlign: TextAlign.center,
            style: context.text.titleLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _HelpPill(
              onTap: () => context.push<void>(AppRoutes.helpCentre),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpPill extends StatelessWidget {
  const _HelpPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.headset_mic_outlined,
                size: AppSizes.iconMd,
                color: colors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Help',
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar, name and contact line.
class _Identity extends StatelessWidget {
  const _Identity({required this.me});

  final Me? me;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        ProfileAvatar(
          photoUrl: me?.photoUrl,
          avatarKey: me?.avatarKey,
          diameter: 112,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          me?.name ?? ' ',
          style: context.text.titleLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (me?.contactLine != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            me!.contactLine!,
            style: context.text.bodyMedium?.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// The three counters. A count still loading shows an em dash rather than a
/// zero — "0 Gifts Given" and "we don't know yet" are different statements.
class _CountsRow extends StatelessWidget {
  const _CountsRow({required this.counts});

  final ProfileCounts counts;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Row(
      children: [
        Expanded(
          child: _CountTile(value: counts.given, label: 'Gifts\nGiven'),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _CountTile(value: counts.received, label: 'Gifts\nReceived'),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _CountTile(
            value: counts.eventsAndInvites,
            label: 'Events\n& Invites',
          ),
        ),
      ],
    ),
  );
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.value, required this.label});

  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text(
            value?.toString() ?? '—',
            style: context.text.headlineSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// One of the two white cards, with an optional all-caps heading.
class _Card extends StatelessWidget {
  const _Card({required this.rows, this.title, this.footer});

  final List<Widget> rows;
  final String? title;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                title!,
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: 0.4,
                ),
              ),
            )
          else
            const SizedBox(height: AppSpacing.sm),
          ...rows,
          ?footer,
        ],
      ),
    );
  }
}

/// One tappable row: icon, label, chevron, hairline.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppSizes.iconLg,
              color: iconColor ?? colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                label,
                style: context.text.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: AppSizes.iconMd,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// The two outlined red buttons at the foot of the second card.
class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.onTap,
    this.emphasised = false,
  });

  final String label;
  final VoidCallback onTap;

  /// "DELETE ACCOUNT" draws its label in the danger colour too; "LOGOUT"
  /// keeps a plum label inside a red outline, as the frame does.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.danger),
          foregroundColor: emphasised ? colors.danger : colors.primary,
        ),
        child: Text(label),
      ),
    );
  }
}
