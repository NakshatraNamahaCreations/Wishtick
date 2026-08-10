import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/chat_message.dart';

/// REST half of chat.
///
/// Everything that *changes* anything goes through here even though a socket
/// is open — the backend deliberately routes both transports through one
/// validation and authorization path, and the gateway only delivers. Posting
/// over the socket would be a second way in, with a second set of rules.
class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  Future<List<Chat>> listChats({ChatType? type}) async {
    final json = await _api.get<List<dynamic>>(
      '/chats',
      query: {'type': ?type?.wireValue},
    );
    return json.map((e) => Chat.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Chat> getChat(String chatId) async {
    final json = await _api.get<Map<String, dynamic>>('/chats/$chatId');
    return Chat.fromJson(json);
  }

  /// History, newest first. Pass [before] (a message id) to page back.
  Future<MessagePage> listMessages(
    String chatId, {
    String? before,
    int? limit,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/chats/$chatId/messages',
      query: {'before': ?before, 'limit': ?limit},
    );
    return MessagePage.fromJson(json);
  }

  /// Posts a message. Connected clients — including this one — receive it
  /// again as `message:new`, which is why the screen de-duplicates by id.
  ///
  /// [surprise] hides it from the recipient of a hidden group gift.
  Future<ChatMessage> postMessage(
    String chatId, {
    String? body,
    String? replyToId,
    List<String>? attachmentMediaIds,
    bool? surprise,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/chats/$chatId/messages',
      body: {
        'body': ?body,
        'replyToId': ?replyToId,
        'attachmentMediaIds': ?attachmentMediaIds,
        'surprise': ?surprise,
      },
    );
    return ChatMessage.fromJson(json);
  }

  Future<ChatMessage> editMessage(String messageId, String body) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/messages/$messageId',
      body: {'body': body},
    );
    return ChatMessage.fromJson(json);
  }

  /// Soft delete — the envelope survives so replies do not dangle.
  Future<ChatMessage> deleteMessage(String messageId) async {
    final json = await _api.delete<Map<String, dynamic>>(
      '/messages/$messageId',
    );
    return ChatMessage.fromJson(json);
  }

  /// Toggles the emoji: posting the same one again removes it.
  Future<ChatMessage> react(String messageId, String emoji) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/messages/$messageId/reactions',
      body: {'emoji': emoji},
    );
    return ChatMessage.fromJson(json);
  }

  /// Marks read up to [messageId], or the latest when omitted.
  Future<int> markRead(String chatId, {String? messageId}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/chats/$chatId/read',
      body: {'messageId': ?messageId},
    );
    return json['unreadCount'] as int? ?? 0;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});
