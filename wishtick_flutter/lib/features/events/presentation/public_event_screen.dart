import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/pending_link.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/invite_repository.dart';

/// What `https://wishtick.com/e/<slug>` opens — a public event's open
/// invitation.
///
/// It resolves rather than renders: a share link names nobody, so the first
/// thing to establish is *who* opened it, and only then can it become an
/// invitation with an accept and a decline on it. Once the join succeeds this
/// screen replaces itself with `/i/<token>`, which is the same invite screen a
/// personally-addressed invitation opens. There is deliberately no second way
/// to view or answer an invite.
///
/// [AppRoutes.invite] is reached with `pushReplacement`, not `push`: backing
/// out of the invitation should leave the app, not return here to join again.
class PublicEventScreen extends ConsumerStatefulWidget {
  const PublicEventScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<PublicEventScreen> createState() => _PublicEventScreenState();
}

class _PublicEventScreenState extends ConsumerState<PublicEventScreen> {
  String? _error;
  bool _needsSignIn = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    if (mounted) {
      setState(() {
        _error = null;
        _needsSignIn = false;
      });
    }

    // Someone arriving from the store has just installed the app and is signed
    // out. Joining needs an account, so this is the one link that cannot be
    // answered anonymously — say so rather than failing with a 401.
    if (!ref.read(sessionProvider).isAuthenticated) {
      if (mounted) setState(() => _needsSignIn = true);
      return;
    }

    try {
      final token = await ref
          .read(inviteRepositoryProvider)
          .joinBySlug(widget.slug);
      if (!mounted) return;
      context.pushReplacement(AppRoutes.invite(token));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = switch (e.code) {
          // The server refuses to say which of these it is — see joinBySlug.
          'EVENT_NOT_FOUND' =>
            'This invitation is no longer available. The link may have expired, '
                'or the host may have cancelled the event.',
          'CANNOT_INVITE_HOST' => 'You are hosting this event.',
          'INVITE_LIMIT_REACHED' => 'This event is full.',
          _ => e.message,
        };
      });
    }
  }

  /// Sends them to sign in, leaving this link behind to be returned to.
  ///
  /// Without the hand-off the router's own rule takes over the moment they are
  /// authenticated — auth flow → Home — and the invitation they tapped is
  /// gone, with nothing on Home to say it ever existed.
  void _signIn() {
    ref
        .read(pendingDeepLinkProvider)
        .remember(AppRoutes.publicEvent(widget.slug));
    unawaited(context.push(AppRoutes.welcome));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: switch ((_needsSignIn, _error)) {
              (true, _) => _SignInPrompt(onSignIn: _signIn),
              (_, final String message) => _Problem(
                message: message,
                onRetry: () => unawaited(_resolve()),
              ),
              _ => const CircularProgressIndicator(),
            },
          ),
        ),
      ),
    );
  }
}

/// The state a link from the store lands in: installed, opened, signed out.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.celebration_outlined,
          size: AppSizes.avatarLg,
          color: colors.primary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'You’re invited',
          textAlign: TextAlign.center,
          style: context.text.headlineSmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sign in to see the invitation and let the host know whether you can '
          'make it.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: FilledButton(
            onPressed: onSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: colors.cta,
              foregroundColor: colors.onCta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: const Text('Sign in'),
          ),
        ),
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.link_off, size: AppSizes.avatarMd, color: colors.textMuted),
        const SizedBox(height: AppSpacing.lg),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
