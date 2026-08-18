import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';
import '../domain/thank_you_note.dart';

/// The notification centre's rows (`324:1392`).
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationsRepositoryProvider).list(limit: 100);
});

/// How many are unread — the badge on the bell.
final unreadCountProvider = Provider<int>((ref) {
  final rows = ref.watch(notificationsProvider).value;
  return rows == null ? 0 : rows.where((n) => !n.read).length;
});

/// The notification settings.
final notificationPreferencesProvider = FutureProvider<NotificationPreferences>(
  (ref) => ref.watch(notificationsRepositoryProvider).preferences(),
);

/// Every thank-you note the caller owns.
final thankYouNotesProvider = FutureProvider<List<ThankYouNote>>((ref) {
  return ref.watch(notificationsRepositoryProvider).thankYouNotes();
});

/// One note, by id — what the compose and preview screens read.
final thankYouNoteProvider = FutureProvider.family<ThankYouNote, String>((
  ref,
  id,
) {
  return ref.watch(notificationsRepositoryProvider).thankYouNote(id);
});

/// The unsent note for one gift, if there is one.
///
/// Looked up through the list rather than a dedicated endpoint: a person has a
/// handful of notes, and the gift-arrival screen (`2012:72`) needs to know
/// whether to offer "Say Thanks" or "Thank-you sent".
final thankYouForGiftProvider = Provider.family<ThankYouNote?, String>((
  ref,
  giftId,
) {
  final notes = ref.watch(thankYouNotesProvider).value;
  if (notes == null) return null;
  for (final note in notes) {
    if (note.giftId == giftId) return note;
  }
  return null;
});
