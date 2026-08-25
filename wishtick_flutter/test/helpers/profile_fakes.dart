import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/gifting/data/gifting_repository.dart';
import 'package:wishtick_flutter/features/gifting/domain/gift.dart';
import 'package:wishtick_flutter/features/gifting/domain/gift_list_item.dart';
import 'package:wishtick_flutter/features/notifications/data/notifications_repository.dart';
import 'package:wishtick_flutter/features/notifications/domain/app_notification.dart';
import 'package:wishtick_flutter/features/notifications/domain/thank_you_note.dart';
import 'package:wishtick_flutter/features/profile/data/profile_repository.dart';
import 'package:wishtick_flutter/features/profile/domain/me.dart';

// ── Builders ────────────────────────────────────────────────────────────────

Me buildMe({
  String id = 'u_1',
  String? displayName = 'Ananya',
  String? username = 'ananya',
  String? email = 'ananya@example.com',
  String? avatarKey = 'avatar_01',
  String? photoUrl,
  String? gender = 'female',
  String? dateOfBirth = '2000-01-01',
}) => Me(
  id: id,
  email: email,
  phone: null,
  emailVerified: true,
  phoneVerified: false,
  displayName: displayName,
  username: username,
  photoUrl: photoUrl,
  avatarKey: avatarKey,
  gender: gender,
  bio: null,
  dateOfBirth: dateOfBirth,
  timezone: 'Asia/Kolkata',
  city: null,
  country: null,
  onboardingCompleted: true,
  createdAt: DateTime(2026),
);

GiftListItem buildGiftRow({
  String id = 'g_1',
  String title = 'Nike Air Max Sneakers',
  String? counterpartyName = 'Rohan',
  bool isGroup = false,
  bool thankYouSent = false,
  DateTime? deliveredAt,
  DateTime? expiresAt,
  int? amountMinor = 1099900,
  GiftStatus status = GiftStatus.fulfilled,
}) => GiftListItem(
  id: id,
  itemId: 'i_1',
  wishlistId: 'wl_1',
  status: status,
  mode: GiftMode.online,
  isGroup: isGroup,
  title: title,
  imageUrl: null,
  amountMinor: amountMinor,
  currency: 'INR',
  counterpartyName: counterpartyName,
  deliveredAt: deliveredAt,
  expiresAt: expiresAt,
  thankYouSent: thankYouSent,
  createdAt: DateTime(2026, 7, 1),
);

AppNotification buildNotification({
  String id = 'n_1',
  String type = 'gift_fulfilled',
  NotificationCategory category = NotificationCategory.gifts,
  String title = 'Your gift has been delivered',
  String body = 'Dyson Air Wrap Hairstyling Tool',
  bool read = false,
  DateTime? createdAt,
  String refId = 'g_1',
}) => AppNotification(
  id: id,
  type: type,
  category: category,
  title: title,
  body: body,
  payload: const {},
  refId: refId,
  read: read,
  createdAt: createdAt ?? DateTime.now(),
);

ThankYouNote buildThankYou({
  String id = 'ty_1',
  String giftId = 'g_1',
  ThankYouStatus status = ThankYouStatus.draft,
  ThankYouKind kind = ThankYouKind.text,
  String? mediaUrl,
  String body = 'Thank you Rohan, I love it.',
  String gifterName = 'Rohan',
}) => ThankYouNote(
  id: id,
  giftId: giftId,
  status: status,
  kind: kind,
  mediaUrl: mediaUrl,
  subject: 'Thank you',
  body: body,
  recipientName: 'Ananya',
  gifterName: gifterName,
  itemTitle: 'Nike Air Max Sneakers',
  eventTitle: null,
  scheduledFor: null,
  sentAt: status == ThankYouStatus.sent ? DateTime(2026, 7, 2) : null,
  createdAt: DateTime(2026, 7, 1),
);

// ── Fakes ───────────────────────────────────────────────────────────────────

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({Me? me}) : me = me ?? buildMe();

  Me me;
  ApiException? failure;
  int deleteCalls = 0;

  /// The last arguments `updateProfile` was called with, so a test can assert
  /// on the *unchanged* sentinel as well as on the values sent.
  Map<String, Object?>? lastUpdate;

  @override
  Future<Me> getMe() async {
    final f = failure;
    if (f != null) throw f;
    return me;
  }

  @override
  Future<Me> updateProfile({
    String? displayName,
    Object? bio = ProfileRepository.unchanged,
    Object? dateOfBirth = ProfileRepository.unchanged,
    Object? gender = ProfileRepository.unchanged,
    String? timezone,
    Object? photoMediaId = ProfileRepository.unchanged,
    Object? avatarKey = ProfileRepository.unchanged,
    String? email,
  }) async {
    final f = failure;
    if (f != null) throw f;
    lastUpdate = {
      'displayName': displayName,
      'bio': bio,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'photoMediaId': photoMediaId,
      'avatarKey': avatarKey,
      'email': email,
    };
    return me;
  }

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
  }
}

class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({
    List<AppNotification>? notifications,
    List<ThankYouNote>? notes,
    NotificationPreferences? preferences,
  }) : notifications = notifications ?? [],
       notes = notes ?? [],
       prefs =
           preferences ??
           const NotificationPreferences(
             disabled: {},
             timezone: 'Asia/Kolkata',
             quietHoursEnabled: false,
             quietStartHour: null,
             quietEndHour: null,
             thankYouAutoSend: true,
           );

  final List<AppNotification> notifications;
  final List<ThankYouNote> notes;

  /// Named `prefs` because `preferences` is the repository's own method.
  NotificationPreferences prefs;

  ApiException? failure;
  final readIds = <String>[];
  Set<String>? lastDisabled;
  final sentNoteIds = <String>[];
  Map<String, Object?>? lastEdit;

  @override
  Future<List<AppNotification>> list({int? limit, bool? unreadOnly}) async {
    final f = failure;
    if (f != null) throw f;
    return List.of(notifications);
  }

  @override
  Future<void> markRead(String id) async => readIds.add(id);

  @override
  Future<void> markAllRead() async =>
      readIds.addAll(notifications.map((n) => n.id));

  @override
  Future<NotificationPreferences> preferences() async => prefs;

  @override
  Future<NotificationPreferences> updatePreferences({
    Set<String>? disabled,
    String? timezone,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
    bool? thankYouAutoSend,
  }) async {
    if (disabled != null) lastDisabled = disabled;
    prefs = NotificationPreferences(
      disabled: disabled ?? prefs.disabled,
      timezone: timezone ?? prefs.timezone,
      quietHoursEnabled: quietHoursEnabled ?? prefs.quietHoursEnabled,
      quietStartHour: quietStartHour ?? prefs.quietStartHour,
      quietEndHour: quietEndHour ?? prefs.quietEndHour,
      thankYouAutoSend: thankYouAutoSend ?? prefs.thankYouAutoSend,
    );
    return prefs;
  }

  @override
  Future<List<ThankYouNote>> thankYouNotes() async => List.of(notes);

  @override
  Future<ThankYouNote> thankYouNote(String id) async =>
      notes.firstWhere((n) => n.id == id);

  @override
  Future<ThankYouNote> editThankYou(
    String id, {
    String? subject,
    String? body,
    ThankYouKind? kind,
    String? mediaId,
  }) async {
    lastEdit = {
      'subject': subject,
      'body': body,
      'kind': kind,
      'mediaId': mediaId,
    };
    return notes.firstWhere((n) => n.id == id);
  }

  @override
  Future<ThankYouNote> sendThankYou(String id) async {
    sentNoteIds.add(id);
    final index = notes.indexWhere((n) => n.id == id);
    final sent = buildThankYou(id: id, status: ThankYouStatus.sent);
    notes[index] = sent;
    return sent;
  }

  @override
  Future<ThankYouNote> skipThankYou(String id) async =>
      notes.firstWhere((n) => n.id == id);

  @override
  Future<String> registerDevice({
    required String token,
    required String platform,
    String? deviceName,
  }) async => 'device_1';

  @override
  Future<void> unregisterDevice(String token) async {}
}

class FakeGiftListRepository implements GiftingRepository {
  FakeGiftListRepository({
    List<GiftListItem>? received,
    List<GiftListItem>? given,
    List<GiftListItem>? onHold,
  }) : received = received ?? [],
       given = given ?? [],
       onHold = onHold ?? [];

  final List<GiftListItem> received;
  final List<GiftListItem> given;
  final List<GiftListItem> onHold;
  ApiException? failure;

  @override
  Future<List<GiftListItem>> listReceived() async {
    final f = failure;
    if (f != null) throw f;
    return List.of(received);
  }

  @override
  Future<List<GiftListItem>> listGiven() async {
    final f = failure;
    if (f != null) throw f;
    return List.of(given);
  }

  @override
  Future<List<GiftListItem>> listOnHold() async {
    final f = failure;
    if (f != null) throw f;
    return List.of(onHold);
  }

  // Nothing else in these screens touches the gifting surface.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
