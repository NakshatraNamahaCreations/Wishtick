import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../onboarding/domain/profile_draft.dart';
import '../data/profile_repository.dart';
import '../domain/me.dart';
import 'profile_providers.dart';

/// The Edit Profile form (`90:21`).
@immutable
class EditProfileState {
  const EditProfileState({
    this.name = '',
    this.email = '',
    this.dateOfBirth,
    this.gender,
    this.photoMediaId,
    this.photoLocalPath,
    this.avatarKey,
    this.busy = false,
    this.uploadingPhoto = false,
    this.error,
    this.saved = false,
  });

  final String name;
  final String email;
  final DateTime? dateOfBirth;
  final Gender? gender;

  /// A freshly uploaded photo, not yet saved.
  final String? photoMediaId;

  /// Its local file, so the circle updates before the round trip finishes.
  final String? photoLocalPath;

  final String? avatarKey;
  final bool busy;
  final bool uploadingPhoto;
  final String? error;
  final bool saved;

  /// `YYYY-MM-DD` — a birthday has no time of day, and sending a timestamp
  /// shifts it a day either side of the date line.
  String? get dateOfBirthWire => dateOfBirth == null
      ? null
      : '${dateOfBirth!.year.toString().padLeft(4, '0')}-'
            '${dateOfBirth!.month.toString().padLeft(2, '0')}-'
            '${dateOfBirth!.day.toString().padLeft(2, '0')}';

  String get dateOfBirthDisplay => dateOfBirth == null
      ? ''
      : '${dateOfBirth!.day.toString().padLeft(2, '0')}/'
            '${dateOfBirth!.month.toString().padLeft(2, '0')}/'
            '${dateOfBirth!.year}';

  bool get isComplete =>
      name.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      dateOfBirth != null &&
      gender != null;

  EditProfileState copyWith({
    String? name,
    String? email,
    DateTime? dateOfBirth,
    Gender? gender,
    String? photoMediaId,
    String? photoLocalPath,
    String? avatarKey,
    bool? busy,
    bool? uploadingPhoto,
    String? error,
    bool clearError = false,
    bool clearDateOfBirth = false,
    bool? saved,
  }) => EditProfileState(
    name: name ?? this.name,
    email: email ?? this.email,
    dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
    gender: gender ?? this.gender,
    photoMediaId: photoMediaId ?? this.photoMediaId,
    photoLocalPath: photoLocalPath ?? this.photoLocalPath,
    avatarKey: avatarKey ?? this.avatarKey,
    busy: busy ?? this.busy,
    uploadingPhoto: uploadingPhoto ?? this.uploadingPhoto,
    error: clearError ? null : (error ?? this.error),
    saved: saved ?? this.saved,
  );
}

class EditProfileController extends Notifier<EditProfileState> {
  @override
  EditProfileState build() {
    // Seeded from the loaded profile when there is one; the screen calls
    // [hydrate] again once `meProvider` resolves.
    final me = ref.watch(meProvider).value;
    return me == null ? const EditProfileState() : _from(me);
  }

  static EditProfileState _from(Me me) => EditProfileState(
    name: me.displayName ?? '',
    email: me.email ?? '',
    dateOfBirth: me.dateOfBirth == null
        ? null
        : DateTime.tryParse(me.dateOfBirth!),
    gender: Gender.fromWire(me.gender),
    avatarKey: me.avatarKey,
  );

  void setName(String value) => state = state.copyWith(name: value);
  void setEmail(String value) => state = state.copyWith(email: value);
  void setDateOfBirth(DateTime value) =>
      state = state.copyWith(dateOfBirth: value);

  /// Backs out of a committed date of birth — see
  /// `ProfileFormController.clearDateOfBirth` (onboarding's counterpart) for
  /// why the manual-entry field needs this.
  void clearDateOfBirth() => state = state.copyWith(clearDateOfBirth: true);
  void setGender(Gender value) => state = state.copyWith(gender: value);

  /// A picked avatar clears any uploaded photo, and vice versa: the backend
  /// stores both fields but shows one, and leaving the other set would make
  /// "Or" mean "and".
  void setAvatar(String key) => state = state.copyWith(
    avatarKey: key,
    photoMediaId: '',
    photoLocalPath: '',
  );

  void setPhoto({required String mediaId, required String localPath}) =>
      state = state.copyWith(
        photoMediaId: mediaId,
        photoLocalPath: localPath,
        avatarKey: '',
      );

  void setUploading(bool value) =>
      state = state.copyWith(uploadingPhoto: value, clearError: value);

  void fail(String message) =>
      state = state.copyWith(error: message, uploadingPhoto: false);

  Future<bool> save() async {
    if (!state.isComplete) {
      state = state.copyWith(error: 'Please fill in every field.');
      return false;
    }

    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            displayName: state.name.trim(),
            email: state.email.trim(),
            dateOfBirth: state.dateOfBirthWire,
            gender: state.gender?.wireValue,
            // Three states, not two. `null` means the user never touched the
            // photo, so it is left alone; `''` means they picked an avatar
            // instead, which *clears* it; anything else is a fresh upload.
            photoMediaId: switch (state.photoMediaId) {
              null => ProfileRepository.unchanged,
              '' => null,
              final id => id,
            },
            avatarKey: switch (state.avatarKey) {
              null => ProfileRepository.unchanged,
              '' => null,
              final key => key,
            },
          );
      ref.invalidate(meProvider);
      state = state.copyWith(busy: false, saved: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }
}

final editProfileProvider =
    NotifierProvider<EditProfileController, EditProfileState>(
      EditProfileController.new,
    );
