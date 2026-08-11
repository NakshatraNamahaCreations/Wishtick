import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/network/api_config.dart';
import '../../../core/network/token_storage.dart';
import '../domain/chat_message.dart';

/// Server → client event names, mirroring the backend's `WS_EVENT`.
abstract final class ChatEvents {
  static const join = 'join_chat';
  static const leave = 'leave_chat';
  static const typing = 'typing';

  static const messageNew = 'message:new';
  static const messageUpdated = 'message:updated';
  static const messageDeleted = 'message:deleted';
  static const reactionChanged = 'reaction:changed';
  static const read = 'read';
  static const presence = 'presence';
  static const error = 'error';
}

/// What the screen reacts to. One sealed-ish family rather than five streams,
/// so ordering between them is preserved.
@immutable
sealed class ChatEvent {
  const ChatEvent();
}

/// A message arrived, was edited, was deleted, or its reactions changed — all
/// four carry a whole message, so all four land here and the screen splices by
/// id. Delete is not special: the server sends the stripped envelope.
class ChatMessageEvent extends ChatEvent {
  const ChatMessageEvent(this.message);

  final ChatMessage message;
}

/// Transport state, so the screen can say "reconnecting" instead of silently
/// going stale.
class ChatConnectionEvent extends ChatEvent {
  const ChatConnectionEvent(this.connected, {this.error});

  final bool connected;
  final String? error;
}

/// The seam the controller talks to.
///
/// An interface rather than the concrete socket so a test can drive the
/// controller without a platform channel: [ChatSocket] reaches secure storage
/// for the handshake token, which does not exist under `flutter test`.
abstract interface class ChatSocketPort {
  Stream<ChatEvent> get events;
  Future<void> connect(String chatId);
  void leave(String chatId);
  Future<void> dispose();
}

/// Live delivery for one chat.
///
/// Read-only by design: the backend routes every mutation through REST so one
/// authorization path serves both transports. This opens the socket, joins the
/// room, and turns the four message events into a single stream.
class ChatSocket implements ChatSocketPort {
  ChatSocket(this._tokens);

  final TokenStorage _tokens;

  io.Socket? _socket;
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Stream<ChatEvent> get events => _controller.stream;

  bool get isConnected => _socket?.connected ?? false;

  @override
  Future<void> connect(String chatId) async {
    if (_socket != null) return;

    // The gateway authenticates at the handshake, before the connection is
    // established, so a missing token must not even attempt to connect — it
    // would come back as connect_error and look like a network fault.
    final token = await _tokens.readAccessToken();
    if (token == null) {
      _controller.add(
        const ChatConnectionEvent(false, error: 'Not signed in.'),
      );
      return;
    }

    final socket = io.io(
      '${ApiConfig.host}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      socket.emit(ChatEvents.join, {'chatId': chatId});
      _controller.add(const ChatConnectionEvent(true));
    });
    socket.onDisconnect(
      (_) => _controller.add(const ChatConnectionEvent(false)),
    );
    socket.onConnectError(
      (e) => _controller.add(
        ChatConnectionEvent(false, error: 'Could not reach the chat.'),
      ),
    );

    for (final event in [
      ChatEvents.messageNew,
      ChatEvents.messageUpdated,
      ChatEvents.messageDeleted,
      ChatEvents.reactionChanged,
    ]) {
      socket.on(event, (data) {
        final message = _parse(data);
        if (message != null) _controller.add(ChatMessageEvent(message));
      });
    }

    socket.connect();
  }

  /// Tolerates a payload that is not a message rather than killing the stream —
  /// a malformed frame should cost one update, not the whole conversation.
  ChatMessage? _parse(dynamic data) {
    if (data is! Map) return null;
    try {
      return ChatMessage.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  @override
  void leave(String chatId) =>
      _socket?.emit(ChatEvents.leave, {'chatId': chatId});

  @override
  Future<void> dispose() async {
    _socket?.dispose();
    _socket = null;
    await _controller.close();
  }
}

final chatSocketProvider = Provider.autoDispose<ChatSocketPort>((ref) {
  final socket = ChatSocket(ref.watch(tokenStorageProvider));
  ref.onDispose(socket.dispose);
  return socket;
});
