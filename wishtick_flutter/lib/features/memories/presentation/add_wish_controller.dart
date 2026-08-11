import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/memories_repository.dart';
import '../domain/memory.dart';

/// What a wish looks like while it is being composed (`2073:55` and friends).
@immutable
class AddWishState {
  const AddWishState({
    required this.kind,
    this.text = '',
    this.mediaId,
    this.mediaUrl,
    this.fileName,
    this.durationMs = 0,
    this.uploading = false,
    this.busy = false,
    this.error,
  });

  final MemoryWishKind kind;
  final String text;

  /// Set once the file has uploaded and been confirmed.
  final String? mediaId;

  /// The uploaded file's URL.
  ///
  /// The *remote* one, not the picked file's path: the upload has already
  /// finished by the time anything renders it, and previewing exactly what the
  /// capsule will serve is the point of a preview. It also means one code path
  /// for the preview and the story.
  final String? mediaUrl;

  /// What the file was called, for the "picked" line on the compose screen.
  final String? fileName;

  final int durationMs;
  final bool uploading;
  final bool busy;
  final String? error;

  /// The frames count the message as "40/100".
  static const textMax = 100;

  /// A text wish needs words; every other kind needs a file. The message on a
  /// media wish is optional, as its label says.
  bool get canPreview => switch (kind) {
    MemoryWishKind.text => text.trim().isNotEmpty,
    _ => mediaId != null,
  };

  AddWishState copyWith({
    MemoryWishKind? kind,
    String? text,
    String? mediaId,
    String? mediaUrl,
    String? fileName,
    int? durationMs,
    bool? uploading,
    bool? busy,
    String? error,
    bool clearError = false,
    bool clearMedia = false,
  }) => AddWishState(
    kind: kind ?? this.kind,
    text: text ?? this.text,
    mediaId: clearMedia ? null : (mediaId ?? this.mediaId),
    mediaUrl: clearMedia ? null : (mediaUrl ?? this.mediaUrl),
    fileName: clearMedia ? null : (fileName ?? this.fileName),
    durationMs: clearMedia ? 0 : (durationMs ?? this.durationMs),
    uploading: uploading ?? this.uploading,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Composes one wish for one capsule.
///
/// Keyed by the capsule id so two capsules cannot share a half-written wish.
class AddWishController extends Notifier<AddWishState> {
  AddWishController(this.capsuleId);

  final String capsuleId;

  @override
  AddWishState build() => const AddWishState(kind: MemoryWishKind.photo);

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

  void fail(String message) =>
      state = state.copyWith(error: message, uploading: false, busy: false);

  /// Sends it. The capsule swallows it whole — not even the author sees it
  /// again until the capsule opens.
  Future<MemoryWish?> submit() async {
    if (!state.canPreview || state.busy) return null;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final wish = await ref
          .read(memoriesRepositoryProvider)
          .addWish(
            capsuleId,
            kind: state.kind,
            text: state.text.trim().isEmpty ? null : state.text.trim(),
            mediaId: state.mediaId,
          );
      state = state.copyWith(busy: false);
      return wish;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return null;
    }
  }

  String _message(ApiException e) => switch (e.code) {
    'MEMORY_NOT_ACCEPTING_WISHES' =>
      'This memory is closed — it has already opened, or it is full.',
    'MEMORY_WISH_TEXT_REQUIRED' => 'Write something first.',
    'MEMORY_WISH_MEDIA_REQUIRED' => 'Pick a file first.',
    _ => e.message,
  };
}

final addWishProvider =
    NotifierProvider.family<AddWishController, AddWishState, String>(
      AddWishController.new,
    );
