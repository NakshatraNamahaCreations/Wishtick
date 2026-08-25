import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../wishmates/presentation/widgets/person_avatar.dart';
import '../../wishmates/presentation/widgets/wishmate_header.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

/// Every direct thread, newest first (`4177:179`).
///
/// Only `ChatType.direct` — a wishlist or group-gift thread belongs to the
/// thing it is about and is reached from there, not from a list of people.
final directChatsProvider = FutureProvider<List<Chat>>((ref) {
  return ref.watch(chatRepositoryProvider).listChats(type: ChatType.direct);
});

/// "Messages" (`4177:179`).
///
/// Each row is drawn entirely from what `GET /chats` returns: the person comes
/// back as the chat's counterpart and the grey line as its last message, so
/// there is no per-row lookup and no local join against the WishMates list.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _search = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Filtered here rather than on the server: the list is one page of the
  /// people you are already connected to, so it is already in memory, and a
  /// round trip per keystroke would be slower than not searching at all.
  List<Chat> _visible(List<Chat> chats) {
    final term = _term.trim().toLowerCase();
    if (term.isEmpty) return chats;
    return chats.where((chat) {
      final person = chat.counterpart;
      if (person == null) return false;
      return person.name.toLowerCase().contains(term) ||
          person.handle.toLowerCase().contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chats = ref.watch(directChatsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          WishmateHeader(
            bottom: WishmateSearchField(
              controller: _search,
              hintText: 'Search Chats',
              onChanged: (value) => setState(() => _term = value),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(directChatsProvider),
              // Error before loading: Riverpod 3 retries a failed provider with
              // a backoff, so a broken list is *also* loading and a
              // spinner-first switch would never show the failure.
              child: switch (chats) {
                AsyncValue(hasError: true, hasValue: false) => _Message(
                  text: 'Could not load your messages.',
                  onRetry: () => ref.invalidate(directChatsProvider),
                ),
                AsyncValue(hasValue: false) => const Center(
                  child: CircularProgressIndicator(),
                ),
                AsyncValue(:final value?) => _List(
                  chats: _visible(value),
                  emptyText: value.isEmpty
                      ? 'No messages yet. Open a WishMate’s profile and tap '
                            'Message to start one.'
                      : 'No chats match “$_term”.',
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.chats, required this.emptyText});

  final List<Chat> chats;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          'Messages',
          style: context.text.titleMedium?.copyWith(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (chats.isEmpty)
          _Message(text: emptyText)
        else
          for (final chat in chats) _ChatRow(chat: chat),
      ],
    );
  }
}

/// One conversation: face, name, what was last said, when, and an unread dot.
class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final person = chat.counterpart;
    if (person == null) return const SizedBox.shrink();

    final unread = chat.unreadCount > 0;
    final subtitle = _subtitle();

    return InkWell(
      onTap: () => unawaited(context.push(AppRoutes.directChat(person.userId))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            PersonAvatar(person: person),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            // The frame bolds the line while it is unread, and
                            // lets it go light once it has been read.
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (chat.lastMessageAt != null) ...[
                        Text(
                          ' · ${_ago(chat.lastMessageAt!)}',
                          style: context.text.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: AppSpacing.sm,
                height: AppSpacing.sm,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// What the grey line says.
  ///
  /// Several unread messages are summarised ("4+ new messages") rather than
  /// quoted, because quoting only the newest hides that others are waiting
  /// behind it. Otherwise the message speaks for itself — including the
  /// frame's "Sent a message", which is what [MessagePreview.previewText]
  /// falls back to when there is nothing quotable.
  String _subtitle() {
    final last = chat.lastMessage;
    if (last == null) return 'No messages yet';
    if (chat.unreadCount > 1) return '${chat.unreadCount}+ new messages';
    return last.previewText();
  }

  /// "2h", "1 d", "3 w" — the frame's own compression.
  static String _ago(DateTime at) {
    final ago = DateTime.now().difference(at.toLocal());
    if (ago.inMinutes < 1) return 'now';
    if (ago.inMinutes < 60) return '${ago.inMinutes}m';
    if (ago.inHours < 24) return '${ago.inHours}h';
    if (ago.inDays < 7) return '${ago.inDays} d';
    if (ago.inDays < 365) return '${(ago.inDays / 7).floor()} w';
    return DateFormat('MMM y').format(at.toLocal());
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ],
    ),
  );
}
