import 'package:flutter/foundation.dart';

/// What a notification is about — the group the settings screen toggles.
///
/// Wire values mirror the backend's `NotificationCategory`.
enum NotificationCategory {
  account('account', 'Account'),
  gifts('gifts', 'Gifts'),
  groupGifts('group_gifts', 'Group gifts'),
  events('events', 'Events'),
  social('social', 'Social'),
  reels('reels', 'Reels'),
  memories('memories', 'Memories');

  const NotificationCategory(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static NotificationCategory fromWire(String? value) => NotificationCategory
      .values
      .firstWhere((v) => v.wireValue == value, orElse: () => account);
}

/// How a notification reaches someone. `in_app` is always on — it *is* the
/// notification centre — so the settings screen only offers the other three.
enum NotificationChannel {
  inApp('in_app', 'In app'),
  email('email', 'Email'),
  sms('sms', 'SMS'),
  push('push', 'Push');

  const NotificationChannel(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// The channels a person may turn off. In-app is not one of them.
  static const switchable = [email, push, sms];
}

/// One row of the notification centre (`324:1392`).
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    required this.payload,
    required this.refId,
    required this.read,
    required this.createdAt,
  });

  final String id;

  /// The backend's `NotificationType` as a raw string.
  ///
  /// Deliberately not an enum: the server adds types faster than the client
  /// ships, and an unknown value must render as an ordinary row rather than
  /// crash a parse or collapse into a wrong one.
  final String type;
  final NotificationCategory category;
  final String title;
  final String body;

  /// Type-specific extras — a gift id, an item title, a thank-you's media URL.
  final Map<String, dynamic> payload;

  /// The domain object this is about; what a tap navigates to.
  final String refId;
  final bool read;
  final DateTime createdAt;

  /// True for the types that open the gift-arrival screen (`2012:72`).
  bool get isGiftArrival =>
      type == 'gift_fulfilled' || type == 'group_gift_fulfilled';

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? '',
        category: NotificationCategory.fromWire(json['category'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        payload: Map<String, dynamic>.from(
          json['payload'] as Map? ?? const <String, dynamic>{},
        ),
        refId: json['refId'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// The notification settings (`GET /notifications/preferences`).
@immutable
class NotificationPreferences {
  const NotificationPreferences({
    required this.disabled,
    required this.timezone,
    required this.quietHoursEnabled,
    required this.quietStartHour,
    required this.quietEndHour,
    required this.thankYouAutoSend,
  });

  /// The `{category}:{channel}` pairs that are switched **off**.
  ///
  /// Stored as an opt-out set rather than an opt-in one so that a category or
  /// channel added later is on by default — the alternative silently mutes
  /// every new notification for existing users.
  final Set<String> disabled;

  final String timezone;
  final bool quietHoursEnabled;
  final int? quietStartHour;
  final int? quietEndHour;
  final bool thankYouAutoSend;

  static String key(
    NotificationCategory category,
    NotificationChannel channel,
  ) => '${category.wireValue}:${channel.wireValue}';

  bool isOn(NotificationCategory category, NotificationChannel channel) =>
      !disabled.contains(key(category, channel));

  /// The set that results from flipping one switch — what the PATCH sends.
  Set<String> toggled(
    NotificationCategory category,
    NotificationChannel channel, {
    required bool on,
  }) {
    final next = Set<String>.from(disabled);
    if (on) {
      next.remove(key(category, channel));
    } else {
      next.add(key(category, channel));
    }
    return next;
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final quiet = json['quietHours'] as Map<String, dynamic>? ?? const {};
    return NotificationPreferences(
      disabled: (json['disabled'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toSet(),
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
      quietHoursEnabled: quiet['enabled'] as bool? ?? false,
      quietStartHour: quiet['startHour'] as int?,
      quietEndHour: quiet['endHour'] as int?,
      thankYouAutoSend: json['thankYouAutoSend'] as bool? ?? true,
    );
  }
}
