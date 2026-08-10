import 'dart:async';

import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/chat/data/chat_repository.dart';
import 'package:wishtick_flutter/features/chat/data/chat_socket.dart';
import 'package:wishtick_flutter/features/chat/domain/chat_message.dart';

Chat buildChat({
  String id = 'chat_1',
  String refId = 'gg_1',
  int unreadCount = 0,
  String whoCanPost = 'participants',
  int participantCount = 6,
}) => Chat(
  id: id,
  type: ChatType.groupGift,
  refId: refId,
  unreadCount: unreadCount,
  whoCanPost: whoCanPost,
  participantCount: participantCount,
  lastMessageAt: DateTime(2026, 8, 1, 12),
);

ChatMessage buildMessage({
  String id = 'msg_1',
  String chatId = 'chat_1',
  String? senderId = 'user_2',
  MessageKind kind = MessageKind.text,
  String body = 'I will contribute ₹1000',
  DateTime? createdAt,
  List<MessageReaction> reactions = const [],
  DateTime? deletedAt,
  DateTime? editedAt,
  SystemMessageType systemType = SystemMessageType.unknown,
  Map<String, dynamic>? systemPayload,
}) => ChatMessage(
  id: id,
  chatId: chatId,
  senderId: senderId,
  kind: kind,
  body: body,
  createdAt: createdAt ?? DateTime(2026, 8, 1, 10, 4),
  reactions: reactions,
  deletedAt: deletedAt,
  editedAt: editedAt,
  systemType: systemType,
  systemPayload: systemPayload,
);

ChatMessage buildSystemMessage({
  String id = 'sys_1',
  SystemMessageType type = SystemMessageType.contributionReceived,
  Map<String, dynamic>? payload,
  String body = '',
  DateTime? createdAt,
}) => buildMessage(
  id: id,
  senderId: null,
  kind: MessageKind.system,
  body: body,
  createdAt: createdAt,
  systemType: type,
  systemPayload: payload,
);

/// Stands in for the live socket so a controller test never touches a
/// platform channel. [emit] lets a test act as the server.
class FakeChatSocket implements ChatSocketPort {
  final _controller = StreamController<ChatEvent>.broadcast();
  final joined = <String>[];

  @override
  Stream<ChatEvent> get events => _controller.stream;

  @override
  Future<void> connect(String chatId) async {
    joined.add(chatId);
    _controller.add(const ChatConnectionEvent(true));
  }

  void emit(ChatEvent event) => _controller.add(event);

  @override
  void leave(String chatId) {}

  @override
  Future<void> dispose() async => _controller.close();
}

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    Chat? chat,
    List<ChatMessage>? messages,
    this.nextCursor,
    this.failWith,
    this.markReadFails = false,
  }) : chat = chat ?? buildChat(),
       messages = messages ?? [];

  Chat chat;

  /// Newest first, as the wire returns them.
  List<ChatMessage> messages;
  String? nextCursor;
  Object? failWith;

  /// Read-marking fails independently: it must never take the screen down.
  bool markReadFails;

  final calls = <String>[];

  T _guard<T>(T value) {
    if (failWith != null) throw failWith!;
    return value;
  }

  @override
  Future<List<Chat>> listChats({ChatType? type}) async => _guard([chat]);

  @override
  Future<Chat> getChat(String chatId) async {
    calls.add('getChat');
    return _guard(chat);
  }

  @override
  Future<MessagePage> listMessages(
    String chatId, {
    String? before,
    int? limit,
  }) async {
    calls.add('listMessages:${before ?? '-'}');
    return _guard(MessagePage(items: messages, nextCursor: nextCursor));
  }

  @override
  Future<ChatMessage> postMessage(
    String chatId, {
    String? body,
    String? replyToId,
    List<String>? attachmentMediaIds,
    bool? surprise,
  }) async {
    calls.add('postMessage:$body');
    return _guard(buildMessage(id: 'posted', senderId: 'me', body: body ?? ''));
  }

  @override
  Future<ChatMessage> editMessage(String messageId, String body) async =>
      _guard(buildMessage(id: messageId, body: body));

  @override
  Future<ChatMessage> deleteMessage(String messageId) async {
    calls.add('deleteMessage:$messageId');
    return _guard(
      buildMessage(id: messageId, body: '', deletedAt: DateTime(2026, 8, 1)),
    );
  }

  @override
  Future<ChatMessage> react(String messageId, String emoji) async {
    calls.add('react:$messageId:$emoji');
    return _guard(
      buildMessage(
        id: messageId,
        reactions: [
          MessageReaction(emoji: emoji, count: 1, userIds: const ['me']),
        ],
      ),
    );
  }

  @override
  Future<int> markRead(String chatId, {String? messageId}) async {
    calls.add('markRead');
    if (markReadFails) {
      throw const ApiException(code: 'X', message: 'could not mark read');
    }
    return _guard(0);
  }
}
