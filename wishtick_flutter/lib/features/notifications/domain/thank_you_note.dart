import 'package:flutter/foundation.dart';

/// What the recipient recorded (`2015:271`, `2015:382`, `2209:104`).
///
/// A non-text kind *adds* an attachment; the subject and body are always
/// present, because what reaches the gifter's inbox is an email and no mail
/// client plays a voice note.
enum ThankYouKind {
  text('text'),
  photo('photo'),
  audio('audio'),
  video('video');

  const ThankYouKind(this.wireValue);

  final String wireValue;

  static ThankYouKind fromWire(String? value) => ThankYouKind.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => text,
  );

  bool get needsMedia => this != text;
}

enum ThankYouStatus {
  draft('draft'),
  scheduled('scheduled'),
  sent('sent'),
  skipped('skipped');

  const ThankYouStatus(this.wireValue);

  final String wireValue;

  static ThankYouStatus fromWire(String? value) => ThankYouStatus.values
      .firstWhere((v) => v.wireValue == value, orElse: () => draft);

  /// Once sent, nothing about it can change.
  bool get isEditable => this != sent;
}

/// A thank-you note the gift's recipient sends to the gifter.
///
/// Drafted by the server when a gift is fulfilled — the client never creates
/// one. That is why there is no `create`: a thank-you always has a gift behind
/// it, and one without would be a message with no context.
@immutable
class ThankYouNote {
  const ThankYouNote({
    required this.id,
    required this.giftId,
    required this.status,
    required this.kind,
    required this.mediaUrl,
    required this.subject,
    required this.body,
    required this.recipientName,
    required this.gifterName,
    required this.itemTitle,
    required this.eventTitle,
    required this.scheduledFor,
    required this.sentAt,
    required this.createdAt,
  });

  final String id;
  final String giftId;
  final ThankYouStatus status;
  final ThankYouKind kind;

  /// The recorded photo/voice note/video, when [kind] is not text.
  final String? mediaUrl;
  final String subject;
  final String body;

  /// Who the note is from — the caller.
  final String recipientName;

  /// Who it goes to.
  final String gifterName;
  final String? itemTitle;
  final String? eventTitle;
  final DateTime? scheduledFor;
  final DateTime? sentAt;
  final DateTime createdAt;

  factory ThankYouNote.fromJson(Map<String, dynamic> json) {
    final context = json['context'] as Map<String, dynamic>? ?? const {};
    return ThankYouNote(
      id: json['id'] as String,
      giftId: json['giftId'] as String,
      status: ThankYouStatus.fromWire(json['status'] as String?),
      kind: ThankYouKind.fromWire(json['kind'] as String?),
      mediaUrl: json['mediaUrl'] as String?,
      subject: json['subject'] as String? ?? '',
      body: json['body'] as String? ?? '',
      recipientName: context['recipientName'] as String? ?? '',
      gifterName: context['gifterName'] as String? ?? '',
      itemTitle: context['itemTitle'] as String?,
      eventTitle: context['eventTitle'] as String?,
      scheduledFor: json['scheduledFor'] == null
          ? null
          : DateTime.parse(json['scheduledFor'] as String),
      sentAt: json['sentAt'] == null
          ? null
          : DateTime.parse(json['sentAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
