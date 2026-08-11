import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/currency.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../auth/presentation/session_controller.dart';
import '../../group_gift/domain/group_gift.dart';
import '../../group_gift/presentation/group_gift_controller.dart';
import '../domain/chat_message.dart';
import 'chat_controller.dart';
import 'widgets/chat_bubbles.dart';

/// "Group Chat" (`316:640`).
///
/// The plum header carries the group's funding progress, so the thing the chat
/// exists to coordinate is always on screen — you never have to leave the
/// conversation to find out how close the group is.
class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({
    required this.groupGiftId,
    required this.chatId,
    super.key,
  });

  final String groupGiftId;
  final String chatId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(chatProvider(widget.chatId).notifier).ensureLoaded();
      ref.read(groupGiftProvider(widget.groupGiftId).notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    final ok = await ref.read(chatProvider(widget.chatId).notifier).send(text);
    if (!ok || !mounted) return;
    _composer.clear();
    _jumpToLatest();
  }

  /// The list is bottom-anchored (`reverse: true`), so "the latest" is offset
  /// zero rather than `maxScrollExtent`.
  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0, duration: AppDurations.fast, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider(widget.chatId));
    final gift = ref.watch(groupGiftProvider(widget.groupGiftId)).gift;
    final me = ref.watch(sessionProvider).user?.id;
    final colors = context.colors;

    // Newest at the bottom of the screen means newest first in a reversed
    // list, and the controller keeps them oldest-first for readability.
    final ordered = state.messages.reversed.toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          _ChatHeader(
            gift: gift,
            connected: state.connected,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: state.chat == null
                ? Center(
                    child: state.error != null
                        ? WishtickErrorText(state.error!)
                        : const CircularProgressIndicator(),
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    itemCount: ordered.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= ordered.length) {
                        return _LoadMore(
                          busy: state.loading,
                          onTap: ref
                              .read(chatProvider(widget.chatId).notifier)
                              .loadMore,
                        );
                      }
                      final message = ordered[index];
                      // `ordered` runs newest→oldest, so the *previous* message
                      // in time is the next index.
                      final earlier = index + 1 < ordered.length
                          ? ordered[index + 1]
                          : null;
                      return Column(
                        children: [
                          if (_startsNewDay(earlier, message))
                            DayDivider(date: message.createdAt),
                          ChatMessageTile(
                            message: message,
                            mine: message.isMine(me),
                            myUserId: me,
                            senderName: _nameFor(gift, message.senderId),
                            nameFor: (id) => _nameFor(gift, id),
                            onReact: () => ref
                                .read(chatProvider(widget.chatId).notifier)
                                .react(message.id, '❤️'),
                            onDelete: message.isMine(me) && !message.isDeleted
                                ? () => ref
                                      .read(
                                        chatProvider(widget.chatId).notifier,
                                      )
                                      .deleteMessage(message.id)
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (state.error != null && state.chat != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: WishtickErrorText(state.error!),
            ),
          _Composer(
            controller: _composer,
            enabled: (state.chat?.canPost ?? false) && !state.sending,
            busy: state.sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  /// A day divider goes above the first message of each calendar day.
  bool _startsNewDay(ChatMessage? earlier, ChatMessage current) {
    if (earlier == null) return true;
    final a = earlier.createdAt.toLocal();
    final b = current.createdAt.toLocal();
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  /// Names come from the group's participant list — the chat payload carries
  /// only ids. An unknown sender is "A friend" rather than a raw id.
  String _nameFor(GroupGift? gift, String? senderId) {
    if (senderId == null) return 'Someone';
    for (final p in gift?.participants ?? const <GroupGiftParticipant>[]) {
      if (p.userId == senderId) return p.name;
    }
    return 'A friend';
  }
}

/// The plum header: title, member count, and the funding bar.
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.gift,
    required this.connected,
    required this.onBack,
  });

  final GroupGift? gift;
  final bool connected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.primaryDeep,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    color: colors.textOnDark,
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Group Chat',
                          style: context.text.titleMedium?.copyWith(
                            color: colors.textOnDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (gift != null) ...[
                          Text(
                            gift!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(
                              color: colors.textOnDark,
                            ),
                          ),
                          Text(
                            '${gift!.participantCount} '
                            '${gift!.participantCount == 1 ? 'Member' : 'Members'}',
                            style: context.text.bodySmall?.copyWith(
                              color: colors.textOnDark.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Balances the back button so the title stays centred.
                  const SizedBox(width: AppSizes.minTapTarget),
                ],
              ),
              if (gift != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _ProgressCard(gift: gift!),
              ],
              if (!connected) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Reconnecting…',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textOnDark.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.gift});

  final GroupGift gift;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatInrMinor(gift.collectedAmountMinor)} of '
                  '${formatInrMinor(gift.targetAmountMinor)} Collected',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${gift.percentFunded}%',
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: gift.percentFunded / 100,
              minHeight: AppSpacing.sm,
              backgroundColor: colors.border,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: busy
            ? const SizedBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onTap,
                child: const Text('Load earlier messages'),
              ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool busy;
  final VoidCallback onSend;

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
              Icon(
                Icons.attach_file,
                size: AppSizes.iconMd,
                color: colors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
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

/// "Today" / "14 Jul" between calendar days.
class DayDivider extends StatelessWidget {
  const DayDivider({required this.date, super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final local = date.toLocal();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        isToday ? 'Today' : DateFormat('d MMM').format(local),
        style: context.text.bodySmall?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}
