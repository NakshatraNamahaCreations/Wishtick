import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../gifting/presentation/widgets/celebration_mark.dart';
import 'notification_providers.dart';

/// "Thank You Sent!" (`2209:203`).
class ThankYouSentScreen extends ConsumerWidget {
  const ThankYouSentScreen({required this.noteId, super.key});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final gifterName = ref
        .watch(thankYouNoteProvider(noteId))
        .value
        ?.gifterName;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The frame's confetti-heart is not in `UI_Screen/`; the
                      // brand mark inside the burst stands in, as elsewhere.
                      const CelebrationMark(
                        size: 140,
                        child: Image(
                          image: AssetImage('assets/logo/logo.png'),
                          width: 120,
                          height: 120,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Thank You Sent!',
                        textAlign: TextAlign.center,
                        style: AppTypography.displaySmall.copyWith(
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        gifterName == null
                            ? 'Your thank you message is on its way.'
                            : '$gifterName has received your\nThank you message.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // Back to the Profile *tab*, not the received list.
                  //
                  // Popping would land on the preview, which would offer to
                  // send a note that has already gone. But `go` to the list —
                  // a route pushed over the shell — replaced the whole stack,
                  // so on the device the next back press exited the app
                  // instead of returning anywhere. A shell branch is the only
                  // destination that leaves the bottom nav and a sane history
                  // behind it.
                  onPressed: () => context.go(AppRoutes.profile),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
