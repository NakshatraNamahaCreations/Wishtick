import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/currency.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../domain/chat_message.dart';

/// One row of the conversation — a system card or a message bubble.
class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({
    required this.message,
    required this.mine,
    required this.senderName,
    required this.nameFor,
    this.myUserId,
    this.onReact,
    this.onDelete,
    super.key,
  });

  final ChatMessage message;
  final bool mine;
  final String senderName;

  /// Resolves a user id to a display name. System payloads carry *ids*, not
  /// names, so the card cannot render "Rohan Paid …" without this.
  final String Function(String? userId) nameFor;

  final String? myUserId;
  final VoidCallback? onReact;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return _SystemCard(message: message, nameFor: nameFor);
    }
    return _MessageBubble(
      message: message,
      mine: mine,
      senderName: senderName,
      myUserId: myUserId,
      onReact: onReact,
      onDelete: onDelete,
    );
  }
}

/// A server-posted event — "Group gift Created 🎉", "Rohan Paid ₹1,000".
///
/// Rendered from [ChatMessage.systemType] and the payload rather than from the
/// server's `body`, so the wording is the client's to change. The body is only
/// the fallback for a type this build does not know about — a newer server
/// must not produce a blank card here.
class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.message, required this.nameFor});

  final ChatMessage message;
  final String Function(String? userId) nameFor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, title, detail) = _content(message);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.optionFill,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconLg, color: colors.primaryMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    color: context.headlineBrandColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    detail,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: _Timestamp(at: message.createdAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, String?) _content(ChatMessage m) {
    // The backend redacts `contributorId` for an anonymous contribution, so a
    // null id here is a deliberate withholding, not missing data — "Someone"
    // is the right word for it.
    final anonymous = m.systemPayload?['anonymous'] == true;
    final actor = anonymous
        ? 'Someone'
        : nameFor(
            m.payloadString('contributorId') ?? m.payloadString('userId'),
          );
    final amount = m.payloadAmountMinor('amountMinor');
    final collected = m.payloadAmountMinor('collectedAmountMinor');
    final target = m.payloadAmountMinor('targetAmountMinor');

    final progress = (collected != null && target != null)
        ? 'Goal Updated  ${formatInrMinor(collected)} of ${formatInrMinor(target)}'
        : null;

    return switch (m.systemType) {
      SystemMessageType.groupGiftStarted => (
        Icons.card_giftcard,
        'Group gift Created 🎉',
        m.body.isNotEmpty ? m.body : null,
      ),
      SystemMessageType.userJoined => (
        Icons.person_add_alt,
        '$actor joined',
        null,
      ),
      SystemMessageType.contributionReceived => (
        Icons.account_balance_wallet_outlined,
        amount == null
            ? '$actor chipped in'
            : '$actor Paid ${formatInrMinor(amount)}',
        progress,
      ),
      SystemMessageType.goalReached => (
        Icons.celebration,
        'Goal reached 🎉',
        progress,
      ),
      SystemMessageType.giftPurchased => (
        Icons.shopping_bag_outlined,
        'The gift has been bought',
        null,
      ),
      SystemMessageType.giftFulfilled => (
        Icons.redeem,
        'The gift has been delivered',
        null,
      ),
      // An unrecognised type still renders: the server's own text carries it.
      SystemMessageType.unknown => (
        Icons.info_outline,
        m.body.isNotEmpty ? m.body : 'Update',
        null,
      ),
    };
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.senderName,
    this.myUserId,
    this.onReact,
    this.onDelete,
  });

  final ChatMessage message;
  final bool mine;
  final String senderName;
  final String? myUserId;
  final VoidCallback? onReact;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            CircleAvatar(
              radius: AppSizes.avatarSm / 2,
              backgroundColor: colors.optionFill,
              child: Text(
                senderName.isEmpty
                    ? '?'
                    : senderName.characters.first.toUpperCase(),
                style: context.text.bodySmall?.copyWith(
                  color: colors.primaryMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _Bubble(
                  message: message,
                  mine: mine,
                  senderName: senderName,
                  onLongPress: onDelete,
                ),
                if (message.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final reaction in message.reactions)
                          _ReactionPill(
                            reaction: reaction,
                            mine: reaction.reactedBy(myUserId),
                            onTap: onReact,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!mine) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              onPressed: message.isDeleted ? null : onReact,
              icon: const Icon(Icons.favorite_border),
              iconSize: AppSizes.iconSm,
              color: colors.textMuted,
              visualDensity: VisualDensity.compact,
              tooltip: 'React',
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.senderName,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final String senderName;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.md);

    return Material(
      color: mine ? colors.surfaceSunken : colors.surface,
      borderRadius: radius,
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mine ? 'You' : senderName,
                style: context.text.bodySmall?.copyWith(
                  color: _senderColor(context, message.senderId, mine),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                message.isDeleted ? 'This message was deleted' : message.body,
                style: context.text.bodyLarge?.copyWith(
                  color: message.isDeleted
                      ? colors.textMuted
                      : colors.textPrimary,
                  fontWeight: message.isDeleted
                      ? FontWeight.w400
                      : FontWeight.w600,
                  fontStyle: message.isDeleted
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited) ...[
                    Text(
                      'edited',
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  _Timestamp(at: message.createdAt),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Each speaker gets a stable colour so a busy thread stays readable.
  /// Derived from the id rather than from position — someone's colour must not
  /// change when an earlier message is deleted.
  Color _senderColor(BuildContext context, String? senderId, bool mine) {
    final colors = context.colors;
    if (mine || senderId == null) return colors.textSecondary;
    final palette = [
      colors.info,
      colors.warning,
      colors.primaryMuted,
      colors.brandMark,
      colors.success,
    ];
    return palette[senderId.hashCode.abs() % palette.length];
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({required this.reaction, required this.mine, this.onTap});

  final MessageReaction reaction;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: mine ? colors.accent : colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(reaction.emoji, style: context.text.bodySmall),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${reaction.count}',
                style: context.text.bodySmall?.copyWith(
                  color: colors.textSecondary,
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

class _Timestamp extends StatelessWidget {
  const _Timestamp({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    return Text(
      DateFormat('h:mm a').format(at.toLocal()),
      style: context.text.bodySmall?.copyWith(color: context.colors.textMuted),
    );
  }
}
