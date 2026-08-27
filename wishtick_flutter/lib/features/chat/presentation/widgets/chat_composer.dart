import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';

/// The message field every chat screen sits on.
///
/// Shared rather than copied: `316:640` (group) and `4177:6` (1:1) draw the
/// same pill — field, send — and the only difference is the smiley the 1:1
/// frame adds. Two copies would be two composers that slowly stop matching.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.controller,
    required this.enabled,
    required this.busy,
    required this.onSend,
    this.onEmoji,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool busy;
  final VoidCallback onSend;

  /// Opens the emoji keyboard. The smiley `4177:6` draws between the field and
  /// Send; the group screen passes null and shows no smiley.
  final VoidCallback? onEmoji;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              // No attach button. The frames draw one, but nothing has ever
              // been behind it — it was a bare Icon with no onTap, in both
              // chats — and an affordance that does nothing when pressed is
              // worse than an absent one.
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: enabled
                        ? 'Type message...'
                        : 'You cannot post here',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
              if (onEmoji != null) ...[
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: onEmoji,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    Icons.emoji_emotions_outlined,
                    size: AppSizes.iconLg,
                    color: colors.textMuted,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              _SendButton(busy: busy, onTap: enabled ? onSend : null),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.busy, this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: onTap == null ? colors.border : colors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: busy ? null : onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.minTapTarget - AppSpacing.sm,
          height: AppSizes.minTapTarget - AppSpacing.sm,
          child: busy
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onPrimary,
                  ),
                )
              : Icon(
                  Icons.send,
                  size: AppSizes.iconMd,
                  color: colors.onPrimary,
                ),
        ),
      ),
    );
  }
}
