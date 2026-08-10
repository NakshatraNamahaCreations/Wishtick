import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket.dart';
import '../domain/chat_message.dart';

@immutable
class ChatState {
  const ChatState({
    this.chat,
    this.messages = const [],
    this.nextCursor,
    this.error,
    this.loading = false,
    this.sending = false,
    this.connected = false,
  });

  final Chat? chat;

  /// **Oldest first** — the reverse of the wire order, because that is the
  /// order a conversation is read in.
  final List<ChatMessage> messages;

  /// Null once the whole history has been paged in.
  final String? nextCursor;

  final String? error;
  final bool loading;
  final bool sending;

  /// False while the socket is down. The screen says so rather than quietly
  /// showing a conversation that has stopped updating.
  final bool connected;

  bool get hasMore => nextCursor != null;

  ChatState copyWith({
    Chat? chat,
    List<ChatMessage>? messages,
    String? nextCursor,
    String? error,
    bool? loading,
    bool? sending,
    bool? connected,
    bool clearError = false,
    bool clearCursor = false,
  }) => ChatState(
    chat: chat ?? this.chat,
    messages: messages ?? this.messages,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    error: clearError ? null : (error ?? this.error),
    loading: loading ?? this.loading,
    sending: sending ?? this.sending,
    connected: connected ?? this.connected,
  );
}

/// One chat: history over REST, live updates over the socket.
class ChatController extends Notifier<ChatState> {
  ChatController(this.chatId);

  final String chatId;

  StreamSubscription<ChatEvent>? _sub;

  @override
  ChatState build() {
    // Watched, not just read. `chatSocketProvider` is autoDispose, and a bare
    // `ref.read` establishes no dependency — the socket was collected the
    // moment after it connected, so the server saw an authenticated client
    // that vanished and the screen sat on "Reconnecting…" forever.
    ref.watch(chatSocketProvider);
    ref.onDispose(() {
      _sub?.cancel();
    });
    return const ChatState();
  }

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  Future<void> ensureLoaded() async {
    if (state.chat != null) return;
    await load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repo.getChat(chatId),
        _repo.listMessages(chatId),
      ]);
      final page = results[1] as MessagePage;
      state = ChatState(
        chat: results[0] as Chat,
        // The wire is newest-first; the screen reads oldest-first.
        messages: page.items.reversed.toList(),
        nextCursor: page.nextCursor,
        connected: state.connected,
      );
      await _listen();
      // Opening the chat is reading it. Failing this must not fail the load —
      // an unread badge that lingers is a nuisance, an empty screen is not.
      unawaited(_markReadQuietly());
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> _listen() async {
    if (_sub != null) return;
    final socket = ref.read(chatSocketProvider);
    _sub = socket.events.listen(_onEvent);
    await socket.connect(chatId);
  }

  void _onEvent(ChatEvent event) {
    switch (event) {
      case ChatConnectionEvent(:final connected, :final error):
        state = state.copyWith(connected: connected, error: error);
      case ChatMessageEvent(:final message):
        // Ignore traffic for another room — one socket, and the server may
        // fan out more than this chat.
        if (message.chatId != chatId) return;
        state = state.copyWith(messages: _merge(state.messages, message));
    }
  }

  /// Splices by id: the same message arrives again on edit, delete and every
  /// reaction change, and the sender sees their own post echoed back.
  List<ChatMessage> _merge(List<ChatMessage> current, ChatMessage incoming) {
    final index = current.indexWhere((m) => m.id == incoming.id);
    if (index >= 0) {
      return [...current]..[index] = incoming;
    }
    return [...current, incoming];
  }

  /// Pages further back. Older messages are prepended.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _repo.listMessages(chatId, before: cursor);
      state = state.copyWith(
        loading: false,
        messages: [...page.items.reversed, ...state.messages],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<bool> send(String body) async {
    final text = body.trim();
    if (text.isEmpty || state.sending) return false;
    state = state.copyWith(sending: true, clearError: true);
    try {
      final message = await _repo.postMessage(chatId, body: text);
      // Merged rather than appended: the socket echo for this same message may
      // already have landed, and two copies of your own message is worse than
      // a slightly redundant splice.
      state = state.copyWith(
        sending: false,
        messages: _merge(state.messages, message),
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(sending: false, error: _message(e));
      return false;
    }
  }

  Future<void> react(String messageId, String emoji) async {
    try {
      final updated = await _repo.react(messageId, emoji);
      state = state.copyWith(messages: _merge(state.messages, updated));
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      final updated = await _repo.deleteMessage(messageId);
      state = state.copyWith(messages: _merge(state.messages, updated));
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> _markReadQuietly() async {
    try {
      await _repo.markRead(chatId);
    } on ApiException {
      // Deliberately swallowed — see the call site.
    }
  }

  String _message(ApiException e) => switch (e.code) {
    'CANNOT_POST_IN_CHAT' => 'You cannot post in this chat.',
    'CHAT_RATE_LIMITED' => 'Slow down a moment, then try again.',
    _ => e.message,
  };
}

final chatProvider =
    NotifierProvider.family<ChatController, ChatState, String>(
      ChatController.new,
    );
