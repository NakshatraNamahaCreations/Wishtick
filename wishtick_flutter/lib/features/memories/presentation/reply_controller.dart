import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/memories_repository.dart';
import '../domain/memory.dart';

/// A reply while it is being composed.
///
/// Deliberately shaped like [AddWishState] — it is the same composer, in the
/// same four kinds. What it adds is [recipientIds]: a wish goes into one
/// capsule, whereas a reply is addressed to people, possibly several at once.
@immutable
class ReplyState {
  const ReplyState({
    required this.kind,
    this.text = '',
    this.mediaId,
    this.mediaUrl,
    this.fileName,
    this.durationMs = 0,
    this.recipientIds = const {},
    this.uploading = false,
    this.busy = false,
    this.error,
  });

  final MemoryWishKind kind;
  final String text;
  final String? mediaId;
  final String? mediaUrl;
  final String? fileName;
  final int durationMs;

  /// Who it is addressed to. A set, because the picker toggles.
  final Set<String> recipientIds;

  final bool uploading;
  final bool busy;
  final String? error;

  static const textMax = 100;

  /// Whether there is something worth sending, ignoring who it goes to.
  bool get composed => switch (kind) {
    MemoryWishKind.text => text.trim().isNotEmpty,
    _ => mediaId != null,
  };

  /// Whether it can actually be sent: composed AND addressed.
  bool get canSend =>
      composed && recipientIds.isNotEmpty && !busy && !uploading;

  ReplyState copyWith({
    MemoryWishKind? kind,
    String? text,
    String? mediaId,
    String? mediaUrl,
    String? fileName,
    int? durationMs,
    Set<String>? recipientIds,
    bool? uploading,
    bool? busy,
    String? error,
    bool clearError = false,
    bool clearMedia = false,
  }) => ReplyState(
    kind: kind ?? this.kind,
    text: text ?? this.text,
    mediaId: clearMedia ? null : (mediaId ?? this.mediaId),
    mediaUrl: clearMedia ? null : (mediaUrl ?? this.mediaUrl),
    fileName: clearMedia ? null : (fileName ?? this.fileName),
    durationMs: clearMedia ? 0 : (durationMs ?? this.durationMs),
    recipientIds: recipientIds ?? this.recipientIds,
    uploading: uploading ?? this.uploading,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Composes one reply and sends it to everyone chosen.
///
/// Not keyed by capsule, unlike [AddWishController]. A reply may answer several
/// memories at once — that is the whole point of the recipient picker — so
/// there is one draft, not one per capsule. The capsule the flow was entered
/// from only decides who is ticked to begin with.
class ReplyController extends Notifier<ReplyState> {
  @override
  ReplyState build() => const ReplyState(kind: MemoryWishKind.photo);

  void setKind(MemoryWishKind kind) =>
      state = state.copyWith(kind: kind, clearMedia: true, clearError: true);

  void setText(String value) =>
      state = state.copyWith(text: value, clearError: true);

  void setUploading(bool value) => state = state.copyWith(uploading: value);

  void setMedia({
    required String mediaId,
    required String mediaUrl,
    required String fileName,
    int durationMs = 0,
  }) => state = state.copyWith(
    mediaId: mediaId,
    mediaUrl: mediaUrl,
    fileName: fileName,
    durationMs: durationMs,
    uploading: false,
    clearError: true,
  );

  void clearMedia() => state = state.copyWith(clearMedia: true);

  void toggleRecipient(String userId) {
    final next = {...state.recipientIds};
    if (!next.remove(userId)) next.add(userId);
    state = state.copyWith(recipientIds: next, clearError: true);
  }

  void setRecipients(Set<String> ids) =>
      state = state.copyWith(recipientIds: ids, clearError: true);

  void fail(String message) =>
      state = state.copyWith(error: message, uploading: false, busy: false);

  /// Clears the draft so the next reply starts blank.
  ///
  /// Called after a successful send rather than on leaving the flow: backing
  /// out of the recipient picker to change the message must not lose the media
  /// that was just uploaded.
  void reset() => state = const ReplyState(kind: MemoryWishKind.photo);

  Future<MemoryReply?> submit() async {
    if (!state.canSend) return null;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final reply = await ref
          .read(memoriesRepositoryProvider)
          .sendReply(
            kind: state.kind,
            recipientIds: state.recipientIds.toList(),
            text: state.text.trim().isEmpty ? null : state.text.trim(),
            mediaId: state.mediaId,
          );
      state = state.copyWith(busy: false);
      return reply;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return null;
    }
  }

  String _message(ApiException e) => switch (e.code) {
    'MEMORY_REPLY_NO_AUDIENCE' =>
      'None of those people have sent you a memory any more.',
    'MEMORY_WISH_TEXT_REQUIRED' => 'Write something first.',
    'MEMORY_WISH_MEDIA_REQUIRED' => 'Pick a file first.',
    _ => e.message,
  };
}

final replyProvider = NotifierProvider<ReplyController, ReplyState>(
  ReplyController.new,
);

/// Everyone the viewer may reply to. Fetched once per visit to the flow.
final replyAudienceProvider = FutureProvider<List<ReplyAudienceEntry>>((ref) {
  return ref.watch(memoriesRepositoryProvider).replyAudience();
});

/// The replies shown on one memory's screen.
final memoryRepliesProvider = FutureProvider.family<List<MemoryReply>, String>((
  ref,
  capsuleId,
) {
  return ref.watch(memoriesRepositoryProvider).replies(capsuleId);
});
