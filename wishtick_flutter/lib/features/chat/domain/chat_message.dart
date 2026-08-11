import 'package:flutter/foundation.dart';

enum ChatType {
  wishlist('wishlist'),
  groupGift('group_gift');

  const ChatType(this.wireValue);

  final String wireValue;

  static ChatType fromWire(String? value) => ChatType.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => groupGift,
  );
}

enum MessageKind {
  text('text'),
  system('system'),
  attachment('attachment');

  const MessageKind(this.wireValue);

  final String wireValue;

  static MessageKind fromWire(String? value) => MessageKind.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => text,
  );
}

/// The structured kinds of server-posted message.
///
/// Rendered from the type plus [ChatMessage.systemPayload] rather than from a
/// server-supplied string — the backend's own note says clients localize from
/// these so the copy can change without breaking anyone.
enum SystemMessageType {
  groupGiftStarted('group_gift_started'),
  userJoined('user_joined'),
  contributionReceived('contribution_received'),
  goalReached('goal_reached'),
  giftPurchased('gift_purchased'),
  giftFulfilled('gift_fulfilled'),
  unknown('');

  const SystemMessageType(this.wireValue);

  final String wireValue;

  static SystemMessageType fromWire(String? value) => SystemMessageType.values
      .firstWhere((v) => v.wireValue == value, orElse: () => unknown);
}

@immutable
class MessageReaction {
  const MessageReaction({
    required this.emoji,
    required this.count,
    required this.userIds,
  });

  final String emoji;
  final int count;
  final List<String> userIds;

  bool reactedBy(String? userId) => userId != null && userIds.contains(userId);

  factory MessageReaction.fromJson(Map<String, dynamic> json) =>
      MessageReaction(
        emoji: json['emoji'] as String,
        count: json['count'] as int? ?? 0,
        userIds:
            (json['userIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
}

@immutable
class MessageAttachment {
  const MessageAttachment({required this.mediaId, this.url, this.contentType});

  final String mediaId;
  final String? url;
  final String? contentType;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      MessageAttachment(
        mediaId: json['mediaId'] as String,
        url: json['url'] as String?,
        contentType: json['contentType'] as String?,
      );
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.kind,
    required this.body,
    required this.createdAt,
    this.senderId,
    this.attachments = const [],
    this.replyToId,
    this.reactions = const [],
    this.editedAt,
    this.deletedAt,
    this.systemType = SystemMessageType.unknown,
    this.systemPayload,
  });

  final String id;
  final String chatId;

  /// Null for a system message — the server is the author.
  final String? senderId;

  final MessageKind kind;

  /// Empty for a deleted message: the server keeps the envelope so replies do
  /// not dangle, but strips the body. "This message was deleted" is all there
  /// is to render.
  final String body;

  final List<MessageAttachment> attachments;
  final String? replyToId;
  final List<MessageReaction> reactions;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final SystemMessageType systemType;
  final Map<String, dynamic>? systemPayload;
  final DateTime createdAt;

  bool get isDeleted => deletedAt != null;
  bool get isSystem => kind == MessageKind.system;
  bool get isEdited => editedAt != null && !isDeleted;

  bool isMine(String? userId) => userId != null && senderId == userId;

  /// A payload amount in minor units, or null when the field is absent.
  int? payloadAmountMinor(String key) {
    final value = systemPayload?[key];
    return value is int ? value : null;
  }

  String? payloadString(String key) {
    final value = systemPayload?[key];
    return value is String ? value : null;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    chatId: json['chatId'] as String,
    senderId: json['senderId'] as String?,
    kind: MessageKind.fromWire(json['kind'] as String?),
    body: json['body'] as String? ?? '',
    attachments:
        (json['attachments'] as List<dynamic>?)
            ?.map((e) => MessageAttachment.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    replyToId: json['replyToId'] as String?,
    reactions:
        (json['reactions'] as List<dynamic>?)
            ?.map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    editedAt: json['editedAt'] == null
        ? null
        : DateTime.parse(json['editedAt'] as String),
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.parse(json['deletedAt'] as String),
    systemType: SystemMessageType.fromWire(json['systemType'] as String?),
    systemPayload: json['systemPayload'] as Map<String, dynamic>?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

@immutable
class Chat {
  const Chat({
    required this.id,
    required this.type,
    required this.refId,
    required this.unreadCount,
    required this.whoCanPost,
    required this.participantCount,
    this.lastMessageAt,
  });

  final String id;
  final ChatType type;

  /// The wishlist or group gift this chat hangs off.
  final String refId;

  final DateTime? lastMessageAt;
  final int unreadCount;

  /// `participants` or `moderators`. Drives whether the composer is offered.
  final String whoCanPost;

  final int participantCount;

  bool get canPost => whoCanPost == 'participants';

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json['id'] as String,
    type: ChatType.fromWire(json['type'] as String?),
    refId: json['refId'] as String,
    lastMessageAt: json['lastMessageAt'] == null
        ? null
        : DateTime.parse(json['lastMessageAt'] as String),
    unreadCount: json['unreadCount'] as int? ?? 0,
    whoCanPost: json['whoCanPost'] as String? ?? 'participants',
    participantCount: json['participantCount'] as int? ?? 0,
  );
}

/// One page of history. The server returns newest-first.
@immutable
class MessagePage {
  const MessagePage({required this.items, this.nextCursor});

  final List<ChatMessage> items;
  final String? nextCursor;

  factory MessagePage.fromJson(Map<String, dynamic> json) => MessagePage(
    items:
        (json['items'] as List<dynamic>?)
            ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    nextCursor: json['nextCursor'] as String?,
  );
}
