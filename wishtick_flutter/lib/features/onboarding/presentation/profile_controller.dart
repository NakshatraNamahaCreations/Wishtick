import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/onboarding_repository.dart';
import '../domain/profile_draft.dart';

@immutable
class ProfileFormState {
  const ProfileFormState({
    this.draft = const ProfileDraft(),
    this.busy = false,
    this.error,
    this.fieldErrors = const {},
    this.saved = false,
  });

  final ProfileDraft draft;
  final bool busy;

  /// A whole-form failure (network, conflict).
  final String? error;

  /// Per-field messages, keyed by the field names the API uses.
  final Map<String, String> fieldErrors;

  final bool saved;

  ProfileFormState copyWith({
    ProfileDraft? draft,
    bool? busy,
    String? error,
    Map<String, String>? fieldErrors,
    bool? saved,
    bool clearError = false,
  }) {
    return ProfileFormState(
      draft: draft ?? this.draft,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      fieldErrors: fieldErrors ?? this.fieldErrors,
      saved: saved ?? this.saved,
    );
  }
}

/// Drives "Create Your Profile" — onboarding step 1 of 5.
class ProfileFormController extends Notifier<ProfileFormState> {
  @override
  ProfileFormState build() {
    // Seed from the session so a returning user sees what the server already
    // knows rather than an empty form.
    final user = ref.read(sessionProvider).user;
    return ProfileFormState(draft: ProfileDraft(name: user?.name ?? ''));
  }

  OnboardingRepository get _onboarding =>
      ref.read(onboardingRepositoryProvider);

  void _update(ProfileDraft draft) {
    state = state.copyWith(
      draft: draft,
      clearError: true,
      fieldErrors: const {},
    );
  }

  void setName(String value) => _update(state.draft.copyWith(name: value));
  void setEmail(String value) => _update(state.draft.copyWith(email: value));
  void setDateOfBirth(DateTime value) =>
      _update(state.draft.copyWith(dateOfBirth: value));
  void setGender(Gender value) => _update(state.draft.copyWith(gender: value));

  /// Picking a preset clears any uploaded photo, mirroring the backend.
  void setAvatar(BundledAvatar avatar) =>
      _update(state.draft.copyWith(avatar: avatar, clearPhoto: true));

  void setPhoto(String mediaId) =>
      _update(state.draft.copyWith(photoMediaId: mediaId, clearAvatar: true));

  /// Client-side checks for the four required fields.
  ///
  /// The design shows Continue enabled on an empty form, so tapping it has to
  /// explain what is missing rather than do nothing. Keys match the API's
  /// field names, so a server-side rejection lands under the same field.
  static Map<String, String> _validate(ProfileDraft d) => {
    if (!d.hasName) 'displayName': 'Please enter your name',
    if (d.email.trim().isEmpty)
      'email': 'Please enter your email'
    else if (!d.hasValidEmail)
      'email': "That doesn't look like an email address",
    if (d.dateOfBirth == null)
      'dateOfBirth': 'Please choose your date of birth',
    if (d.gender == null) 'gender': 'Please select your gender',
  };

  /// Returns whether the profile saved — the caller navigates on `true` and
  /// otherwise leaves the form up, where [fieldErrors]/[error] explain why.
  Future<bool> submit() async {
    if (state.busy) return false;

    final invalid = _validate(state.draft);
    if (invalid.isNotEmpty) {
      state = state.copyWith(fieldErrors: invalid, clearError: true);
      return false;
    }

    state = state.copyWith(busy: true, clearError: true, fieldErrors: const {});
    try {
      await _onboarding.saveProfile(state.draft);
      // The saved name/email/photo now live on the server; refresh so the rest
      // of the app sees them.
      await ref.read(sessionProvider.notifier).refreshUser();
      state = state.copyWith(busy: false, saved: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        error: _messageFor(e),
        fieldErrors: _fieldErrorsFor(e),
      );
      return false;
    }
  }

  static String _messageFor(ApiException e) => switch (e.code) {
    'EMAIL_ALREADY_REGISTERED' =>
      'That email is already used by another account.',
    'VALIDATION_FAILED' => 'Please check the highlighted fields.',
    ApiException.codeNetwork ||
    ApiException.codeTimeout => 'No connection. Check your network and retry.',
    _ => e.message,
  };

  static Map<String, String> _fieldErrorsFor(ApiException e) =>
      switch (e.code) {
        'EMAIL_ALREADY_REGISTERED' => const {
          'email': 'Already used by another account',
        },
        _ => const {},
      };
}

/// Auto-disposed so leaving the screen discards a half-filled form.
final profileFormProvider =
    NotifierProvider<ProfileFormController, ProfileFormState>(
      ProfileFormController.new,
    );
