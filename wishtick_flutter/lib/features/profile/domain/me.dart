import 'package:flutter/foundation.dart';

/// The authenticated user with their full profile (`GET /me`).
///
/// One flat-ish object rather than a tree of small ones: every screen that
/// reads it — the Profile hub, Edit Profile, the greeting on Home — wants a
/// handful of fields from across it, and threading three nested models through
/// would buy nothing.
@immutable
class Me {
  const Me({
    required this.id,
    required this.email,
    required this.phone,
    required this.emailVerified,
    required this.phoneVerified,
    required this.displayName,
    required this.username,
    required this.photoUrl,
    required this.avatarKey,
    required this.gender,
    required this.bio,
    required this.dateOfBirth,
    required this.timezone,
    required this.city,
    required this.country,
    required this.onboardingCompleted,
    required this.createdAt,
  });

  final String id;
  final String? email;
  final String? phone;
  final bool emailVerified;
  final bool phoneVerified;

  final String? displayName;

  /// The `@handle`, or null for an account that never claimed one.
  ///
  /// Null is the gate on the whole of WishMates: an account with no handle
  /// is not discoverable, cannot be searched for, and cannot be sent a
  /// request — so the entry points send the user to claim one first rather
  /// than into screens that could only ever come back empty.
  final String? username;

  /// An uploaded photo. Null when the user picked a bundled avatar instead.
  final String? photoUrl;

  /// A bundled avatar key, when there is no [photoUrl].
  final String? avatarKey;
  final String? gender;
  final String? bio;

  /// `YYYY-MM-DD`, not a timestamp — a birthday has no time of day and no
  /// zone, and parsing it as one shifts it a day either side of the date line.
  final String? dateOfBirth;
  final String timezone;
  final String? city;
  final String? country;
  final bool onboardingCompleted;
  final DateTime createdAt;

  /// Whether this account can be found by anybody who does not already know
  /// it — see [username].
  bool get hasHandle => username != null && username!.isNotEmpty;

  /// What the Profile header shows above the contact line.
  String get name => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : 'Your profile';

  /// The `@handle` as it is shown, or null for an account that has not
  /// claimed one.
  ///
  /// This is what sits under the name on the Profile hub. It used to be the
  /// phone number, which is the one thing on that screen a person cannot do
  /// anything with and would rather not have over their shoulder — and unlike
  /// a number, a handle is what other people find them by.
  String? get handle => hasHandle ? '@${username!}' : null;

  /// The contact line — a phone if there is one, else the email.
  ///
  /// No longer the Profile header's subtitle; kept for the places that are
  /// genuinely about how to reach this account.
  String? get contactLine => phone ?? email;

  factory Me.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? const {};
    final contact = profile['contact'] as Map<String, dynamic>? ?? const {};
    final onboarding =
        profile['onboarding'] as Map<String, dynamic>? ?? const {};

    return Me(
      id: json['id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      displayName: profile['displayName'] as String?,
      username: profile['username'] as String?,
      photoUrl: profile['photoUrl'] as String?,
      avatarKey: profile['avatarKey'] as String?,
      gender: profile['gender'] as String?,
      bio: profile['bio'] as String?,
      dateOfBirth: profile['dateOfBirth'] as String?,
      timezone: profile['timezone'] as String? ?? 'Asia/Kolkata',
      city: contact['city'] as String?,
      country: contact['country'] as String?,
      onboardingCompleted: onboarding['completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
