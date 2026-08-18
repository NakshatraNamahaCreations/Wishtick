import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/me.dart';

/// The authenticated user's own profile (`/me`).
///
/// Separate from `OnboardingRepository`, which writes the same underlying
/// document: onboarding is a one-time wizard with its own step bookkeeping,
/// and Edit Profile is an ordinary form the user returns to.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<Me> getMe() async {
    final json = await _api.get<Map<String, dynamic>>('/me');
    return Me.fromJson(json);
  }

  /// Updates profile details (`90:21`).
  ///
  /// The nullable fields take an explicit `null` to *clear* them, so they are
  /// passed through rather than omitted — the map-literal `?` shorthand is
  /// deliberately not used for [bio], [dateOfBirth] and [gender].
  ///
  /// Throws [ApiException] with `MEDIA_NOT_FOUND` (404) for a photo the caller
  /// does not own.
  Future<Me> updateProfile({
    String? displayName,
    Object? bio = unchanged,
    Object? dateOfBirth = unchanged,
    Object? gender = unchanged,
    String? timezone,
    Object? photoMediaId = unchanged,
    Object? avatarKey = unchanged,
    String? email,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/me',
      body: {
        'displayName': ?displayName,
        if (bio != unchanged) 'bio': bio,
        if (dateOfBirth != unchanged) 'dateOfBirth': dateOfBirth,
        if (gender != unchanged) 'gender': gender,
        'timezone': ?timezone,
        if (photoMediaId != unchanged) 'photoMediaId': photoMediaId,
        if (avatarKey != unchanged) 'avatarKey': avatarKey,
        'email': ?email,
      },
    );
    return Me.fromJson(json);
  }

  /// Deletes the account. Irreversible on the server's own terms.
  Future<void> deleteAccount() => _api.delete<void>('/me');

  /// Distinguishes "not passed" from "passed as null", which the profile PATCH
  /// treats as *clear this field*. A plain `null` default could not, and the
  /// difference is load-bearing: sending `photoMediaId: null` on every save
  /// would delete a photo the user never touched.
  static const unchanged = Object();
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});
