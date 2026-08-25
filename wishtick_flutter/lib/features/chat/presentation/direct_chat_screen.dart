import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/curved_bottom_clipper.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../auth/presentation/session_controller.dart';
import '../../wishmates/domain/wishmate.dart';
import '../../wishmates/presentation/widgets/person_avatar.dart';
import '../../wishmates/presentation/wishmates_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';
import 'chat_controller.dart';
import 'chat_list_screen.dart';
import 'widgets/chat_bubbles.dart';
import 'widgets/chat_composer.dart';

/// Resolves the 1:1 thread with one person, creating it on first open.
///
/// Keyed by *user*, not by chat: `POST /chats/direct/:userId` is idempotent —
/// the same pair always lands on the same thread whichever side asks — so
/// every caller can name the person and let this find the conversation. A chat
/// id passed around instead would go stale the moment the other person opened
/// the thread first.
///
/// Throws `NOT_WISHMATES` when there is no accepted link, which the screen
/// renders as a sentence rather than an error: it is the rule working, not a
/// failure. History survives an unfriending; posting does not.
final directChatIdProvider = FutureProvider.family<String, String>((
  ref,
  userId,
) {
  return ref.watch(chatRepositoryProvider).openDirect(userId);
});

/// A 1:1 conversation (`4177:6`).
class DirectChatScreen extends ConsumerWidget {
  const DirectChatScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final chatId = ref.watch(directChatIdProvider(userId));

    return Scaffold(
      backgroundColor: colors.background,
      // Error before loading: Riverpod 3 retries a failed provider, so
      // NOT_WISHMATES would sit behind a spinner rather than saying so.
      body: switch (chatId) {
        AsyncValue(hasError: true, hasValue: false, :final error?) =>
          _CannotOpen(
            error: error,
            onRetry: () => ref.invalidate(directChatIdProvider(userId)),
          ),
        AsyncValue(hasValue: false) => const Center(
          child: CircularProgressIndicator(),
        ),
        AsyncValue(:final value?) => _Thread(chatId: value, userId: userId),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _Thread extends ConsumerStatefulWidget {
  const _Thread({required this.chatId, required this.userId});

  final String chatId;
  final String userId;

  @override
  ConsumerState<_Thread> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<_Thread> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await ref.read(chatProvider(widget.chatId).notifier).ensureLoaded();
      // Opening a thread reads it, which changes its row on `4177:179` — the
      // unread dot and the bolding both come off. Refetched here rather than
      // on the way out, because the back gesture does not run any code of
      // ours and the list would come back still showing the badge.
      if (mounted) ref.invalidate(directChatsProvider);
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_composer.text.trim().isEmpty) return;
    final ok = await ref
        .read(chatProvider(widget.chatId).notifier)
        .send(_composer.text);
    if (!ok || !mounted) return;
    _composer.clear();
    // The list is bottom-anchored (`reverse: true`), so "the latest" is offset
    // zero rather than `maxScrollExtent`.
    if (_scroll.hasClients) {
      unawaited(
        _scroll.animateTo(
          0,
          duration: AppDurations.fast,
          curve: Curves.easeOut,
        ),
      );
    }
  }

  /// A day divider goes above the first message of each calendar day.
  bool _startsNewDay(ChatMessage? earlier, ChatMessage current) {
    if (earlier == null) return true;
    final a = earlier.createdAt.toLocal();
    final b = current.createdAt.toLocal();
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider(widget.chatId));
    final me = ref.watch(sessionProvider).user?.id;
    final person = ref
        .watch(personProfileProvider(widget.userId))
        .value
        ?.person;

    // The controller keeps messages oldest-first for readability; a reversed
    // list wants them newest-first.
    final ordered = state.messages.reversed.toList();

    return Column(
      children: [
        _DirectChatHeader(person: person, connected: state.connected),
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
                      return Center(
                        child: TextButton(
                          onPressed: ref
                              .read(chatProvider(widget.chatId).notifier)
                              .loadMore,
                          child: const Text('Load earlier messages'),
                        ),
                      );
                    }
                    final message = ordered[index];
                    // `ordered` runs newest→oldest, so the *earlier* message
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
                          // In a thread of two there is only one other person,
                          // so a name never has to be looked up by id.
                          senderName: message.isMine(me)
                              ? 'You'
                              : (person?.name ?? 'Them'),
                          nameFor: (id) =>
                              id == me ? 'You' : (person?.name ?? 'Them'),
                          onReact: () => ref
                              .read(chatProvider(widget.chatId).notifier)
                              .react(message.id, '❤️'),
                          onDelete: message.isMine(me) && !message.isDeleted
                              ? () => ref
                                    .read(chatProvider(widget.chatId).notifier)
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
        ChatComposer(
          controller: _composer,
          enabled: !state.sending,
          busy: state.sending,
          onSend: _send,
          // `4177:6` draws a smiley between the field and Send. There is no
          // picker behind it yet, so it puts one in the field rather than
          // opening a sheet no frame specifies.
          onEmoji: () {
            final text = _composer.text;
            _composer
              ..text = '$text🙂'
              ..selection = TextSelection.collapsed(
                offset: _composer.text.length,
              );
          },
        ),
      ],
    );
  }
}

/// The plum header: back, face, name, and "Online" beneath it.
class _DirectChatHeader extends StatelessWidget {
  const _DirectChatHeader({required this.person, required this.connected});

  final PersonIdentity? person;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ClipPath(
      clipper: const CurvedBottomClipper(dip: CurvedBottomClipper.shallow),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: context.gradients.header),
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          bottom: CurvedBottomClipper.shallow + AppSpacing.md,
        ),
        child: Row(
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
            if (person != null) ...[
              PersonAvatar(person: person!, diameter: AppSizes.avatarSm + 8),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        color: colors.textOnDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      // The socket being down is worth more than their
                      // presence: a conversation that has silently stopped
                      // updating looks identical to one nobody is answering.
                      connected ? person!.presenceLabel() : 'Reconnecting…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textOnDark.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const Spacer(),
            IconButton(
              onPressed: null,
              icon: Icon(Icons.more_vert, color: colors.textOnDark),
              tooltip: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

/// What a thread you are not allowed to open looks like.
class _CannotOpen extends StatelessWidget {
  const _CannotOpen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notWishmates =
        error is ApiException &&
        (error as ApiException).code == 'NOT_WISHMATES';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              notWishmates
                  // Stated as the rule, not as a fault: a direct message is the
                  // one channel that reaches someone with nothing else between
                  // you, so the connection is the permission.
                  ? 'You can only message your WishMates.'
                  : 'Could not open this conversation.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (notWishmates)
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back'),
              )
            else
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
