import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../gifting/presentation/gift_list_providers.dart';
import '../data/notifications_repository.dart';
import '../domain/thank_you_note.dart';
import 'notification_providers.dart';

/// The compose screens' shared draft (`2015:271`, `2015:382`, `2209:104`).
@immutable
class ThankYouDraft {
  const ThankYouDraft({
    this.kind = ThankYouKind.text,
    this.message = '',
    this.mediaId,
    this.mediaLocalPath,
    this.mediaUrl,
    this.busy = false,
    this.uploading = false,
    this.error,
  });

  final ThankYouKind kind;
  final String message;

  /// A freshly uploaded attachment, not yet saved to the note.
  final String? mediaId;

  /// Its local file, so the preview draws before the round trip finishes.
  final String? mediaLocalPath;

  /// The attachment already on the note, if any.
  final String? mediaUrl;

  final bool busy;
  final bool uploading;
  final String? error;

  /// The server's own limit (`EditThankYouDto`'s `@MaxLength(2000)`).
  ///
  /// The frame's counter reads `40/100`, and 100 was taken literally until the
  /// device walk: the server drafts a full letter — "Dear Rohan, Thank you so
  /// much for …" — which is 148 characters, so a note opened straight from a
  /// fulfilled gift was *born over the limit* and the field would have
  /// truncated it on the first keystroke. What the compose box edits is the
  /// body of an email, so the only cap that can honestly be shown is the one
  /// the server will actually enforce.
  static const messageMax = 2000;

  /// A media note needs its recording; a text note needs words.
  bool get canPreview => kind.needsMedia
      ? (mediaId != null || mediaUrl != null)
      : message.trim().isNotEmpty;

  ThankYouDraft copyWith({
    ThankYouKind? kind,
    String? message,
    String? mediaId,
    String? mediaLocalPath,
    String? mediaUrl,
    bool? busy,
    bool? uploading,
    String? error,
    bool clearError = false,
    bool clearMedia = false,
  }) => ThankYouDraft(
    kind: kind ?? this.kind,
    message: message ?? this.message,
    mediaId: clearMedia ? null : (mediaId ?? this.mediaId),
    mediaLocalPath: clearMedia ? null : (mediaLocalPath ?? this.mediaLocalPath),
    mediaUrl: clearMedia ? null : (mediaUrl ?? this.mediaUrl),
    busy: busy ?? this.busy,
    uploading: uploading ?? this.uploading,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Edits one thank-you note.
///
/// Keyed by note id rather than gift id: a note is drafted server-side when a
/// gift is fulfilled, so it always exists by the time any of these screens can
/// be reached, and the id is what every call takes.
class ThankYouController extends Notifier<ThankYouDraft> {
  ThankYouController(this.noteId);

  final String noteId;

  @override
  ThankYouDraft build() {
    final note = ref.watch(thankYouNoteProvider(noteId)).value;
    return note == null
        ? const ThankYouDraft()
        : ThankYouDraft(
            kind: note.kind,
            message: note.body,
            mediaUrl: note.mediaUrl,
          );
  }

  void setKind(ThankYouKind kind) {
    // Switching kind drops the attachment: a photo is not a voice note, and
    // keeping it would send the wrong media under the new player.
    state = kind.needsMedia && kind != state.kind
        ? state.copyWith(kind: kind, clearMedia: true, clearError: true)
        : state.copyWith(kind: kind, clearError: true);
  }

  void setMessage(String value) => state = state.copyWith(message: value);

  void setUploading(bool value) =>
      state = state.copyWith(uploading: value, clearError: value);

  void setMedia({required String mediaId, required String localPath}) =>
      state = state.copyWith(mediaId: mediaId, mediaLocalPath: localPath);

  void clearMedia() => state = state.copyWith(clearMedia: true);

  void fail(String message) =>
      state = state.copyWith(error: message, uploading: false, busy: false);

  /// Writes the draft to the note without sending it — what "Preview" does, so
  /// the preview screen renders the server's own copy rather than local state.
  Future<bool> saveDraft() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .editThankYou(
            noteId,
            body: state.message.trim().isEmpty ? null : state.message.trim(),
            kind: state.kind,
            mediaId: state.mediaId,
          );
      ref.invalidate(thankYouNoteProvider(noteId));
      ref.invalidate(thankYouNotesProvider);
      state = state.copyWith(busy: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  Future<bool> send() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref.read(notificationsRepositoryProvider).sendThankYou(noteId);
      ref.invalidate(thankYouNoteProvider(noteId));
      ref.invalidate(thankYouNotesProvider);
      // The received list carries `thankYouSent` per row, so sending changes
      // it too. Without this the card the user came *from* still offered to
      // send a note that had already gone — which is what the device showed.
      ref.invalidate(giftListProvider(GiftListKind.received));
      state = state.copyWith(busy: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }
}

final thankYouDraftProvider =
    NotifierProvider.family<ThankYouController, ThankYouDraft, String>(
      ThankYouController.new,
    );
