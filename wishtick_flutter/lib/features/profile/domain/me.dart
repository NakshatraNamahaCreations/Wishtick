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

  /// What the Profile header shows above the contact line.
  String get name => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : 'Your profile';

  /// The contact line under the name — a phone if there is one, else the email.
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
