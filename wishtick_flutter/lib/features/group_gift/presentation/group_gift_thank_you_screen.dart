import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/group_gift.dart';
import 'group_gift_controller.dart';
import 'widgets/thank_you_sheet.dart';

/// "Thank You from …" (`2219:603`, variant `2288:5`).
///
/// A card the *recipient* writes once the gift has been bought. Both exported
/// frames are the read view; the composer is not designed, so the sheet this
/// screen offers is an addition — see sprints.md.
class GroupGiftThankYouScreen extends ConsumerStatefulWidget {
  const GroupGiftThankYouScreen({required this.groupGiftId, super.key});

  final String groupGiftId;

  @override
  ConsumerState<GroupGiftThankYouScreen> createState() =>
      _GroupGiftThankYouScreenState();
}

class _GroupGiftThankYouScreenState
    extends ConsumerState<GroupGiftThankYouScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(groupGiftProvider(widget.groupGiftId).notifier).ensureLoaded();
    });
  }

  Future<void> _write(GroupGift gift) async {
    final note = await showThankYouSheet(context, existing: gift.thankYouNote);
    if (note == null || !mounted) return;
    await ref
        .read(groupGiftProvider(widget.groupGiftId).notifier)
        .setThankYou(note);
  }

  /// The recipient owns the wishlist the item sits on, which the client cannot
  /// see. It infers from the two things it does know — a host is never the
  /// recipient, and there is nothing to thank anyone for until the gift is
  /// bought — and offers the button optimistically. The server is the real
  /// gate: it answers 403 to anyone but the recipient.
  bool _mayWrite(GroupGift gift) =>
      !gift.canManage &&
      const {
        GroupGiftStatus.purchased,
        GroupGiftStatus.fulfilled,
      }.contains(gift.status);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupGiftProvider(widget.groupGiftId));
    final gift = state.gift;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Thank You')),
      body: gift == null
          ? Center(
              child: state.error != null
                  ? WishtickErrorText(state.error!)
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (gift.hasThankYou)
                  ThankYouCard(
                    note: gift.thankYouNote!,
                    signature: gift.recipientName,
                  )
                else
                  _NotYet(
                    canWrite: _mayWrite(gift),
                    onWrite: () => _write(gift),
                  ),
                if (gift.hasThankYou && _mayWrite(gift)) ...[
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton(
                    onPressed: state.busy ? null : () => _write(gift),
                    child: const Text('Edit your note'),
                  ),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  WishtickErrorText(state.error!),
                ],
              ],
            ),
      backgroundColor: colors.background,
    );
  }
}

class _NotYet extends StatelessWidget {
  const _NotYet({required this.canWrite, required this.onWrite});

  final bool canWrite;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.section),
      child: Column(
        children: [
          Icon(
            Icons.drafts_outlined,
            size: AppSizes.avatarLg,
            color: colors.textMuted,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            canWrite
                ? 'Say thank you to everyone who chipped in.'
                : 'No thank-you note yet.',
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (canWrite) ...[
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: onWrite,
              child: const Text('Write a thank-you note'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The card itself (`2219:603`) — a warm, letter-like panel.
///
/// The design's floral artwork is not exported, so the card is drawn from
/// tokens: the same warm gradient and script headline, without inventing an
/// asset that would not match when the real one arrives.
class ThankYouCard extends StatelessWidget {
  const ThankYouCard({required this.note, this.signature, super.key});

  final String note;
  final String? signature;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            colors.celebrationSubtle,
            colors.surface,
            colors.accentSubtle,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thank\nYou',
            style: context.text.displaySmall?.copyWith(
              color: colors.heartFill,
              fontWeight: FontWeight.w700,
              height: 1.05,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Dear family & friends,',
            style: context.text.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            note,
            style: context.text.bodyMedium?.copyWith(
              color: colors.textPrimary,
              height: 1.6,
            ),
          ),
          // The whole sign-off goes, not just the name: "With warmest
          // regards," dangling over nothing reads as a rendering fault.
          if (signature != null) ...[
            const SizedBox(height: AppSpacing.section),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'With warmest regards,',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    signature!,
                    style: context.text.headlineSmall?.copyWith(
                      color: colors.heartFill,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
