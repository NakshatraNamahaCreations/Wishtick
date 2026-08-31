import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/currency.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../gifting/presentation/widgets/celebration_mark.dart';

/// What the details screen hands this screen after a pledge lands.
///
/// Passed rather than refetched: the amount is what *this* pledge was, which
/// the refreshed gift no longer distinguishes from anyone else's.
typedef ContributionReceipt = ({
  int amountMinor,
  String? hostName,
  String? hostUpiId,
});

/// "Thank You!" (`316:298`) — the confirmation after contributing.
///
/// The frame is drawn for a payment that completed in-app. Wishtick never holds
/// the money, so the same screen also has to say where to send it: this was the
/// only place a contributor could ever learn the host's UPI ID, and it used to
/// be a snackbar that took the answer away with it a few seconds later.
class ContributionSuccessScreen extends StatelessWidget {
  const ContributionSuccessScreen({required this.receipt, super.key});

  final ContributionReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final upiId = receipt.hostUpiId;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: AppSizes.iconSm),
          color: colors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    // The frame's confetti-heart is not in `UI_Screen/`; the
                    // brand mark inside the burst stands in, as on the other
                    // three celebration screens.
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
                      'Thank You!',
                      textAlign: TextAlign.center,
                      style: AppTypography.displaySmall.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Your Contribution of '
                      '${formatInrMinor(receipt.amountMinor)} was successful.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (upiId != null)
                      _SendItBlock(
                        amountMinor: receipt.amountMinor,
                        hostName: receipt.hostName,
                        upiId: upiId,
                      )
                    else
                      // Not silence: a pledge with nowhere to send it looks
                      // like the money already moved.
                      Text(
                        'The host will share where to send it.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: Column(
                children: [
                  Text(
                    'You are making this gift special 🎉',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // Back to the group, which is what this was pushed over.
                      onPressed: () => context.pop(),
                      child: const Text('Continue'),
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

/// Who to pay, and a way to carry the handle to a UPI app without retyping it.
class _SendItBlock extends StatelessWidget {
  const _SendItBlock({
    required this.amountMinor,
    required this.hostName,
    required this.upiId,
  });

  final int amountMinor;
  final String? hostName;
  final String upiId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(
            // The name, not just the handle: "myupi@icic.com" alone does not
            // tell the sender whose account they are about to pay.
            hostName == null
                ? 'Now send ${formatInrMinor(amountMinor)} to the host'
                : 'Now send ${formatInrMinor(amountMinor)} to $hostName',
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            upiId,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: upiId));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('UPI ID copied')));
            },
            icon: const Icon(Icons.copy_outlined, size: AppSizes.iconSm),
            label: const Text('Copy UPI ID'),
          ),
        ],
      ),
    );
  }
}
