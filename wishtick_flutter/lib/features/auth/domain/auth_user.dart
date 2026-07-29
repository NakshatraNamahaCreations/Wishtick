import 'package:flutter/foundation.dart';

/// The authenticated user, as returned by `GET /auth/me` and inside the
/// signup/login envelopes. Mirrors `AuthUserView` on the backend.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.emailVerified,
    required this.phoneVerified,
    required this.roles,
    required this.createdAt,
    this.email,
    this.phone,
    this.name,
  });

  final String id;
  final String? email;
  final String? phone;
  final String? name;
  final bool emailVerified;
  final bool phoneVerified;
  final List<String> roles;
  final DateTime createdAt;

  /// What to greet the user with before they have set a name.
  String get displayName => name?.trim().isNotEmpty ?? false
      ? name!.trim()
      : (phone ?? email ?? 'there');

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      name: json['name'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      roles:
          (json['roles'] as List<dynamic>?)
              ?.map((r) => r.toString())
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.phone == phone &&
      other.name == name &&
      other.emailVerified == emailVerified &&
      other.phoneVerified == phoneVerified;

  @override
  int get hashCode =>
      Object.hash(id, email, phone, name, emailVerified, phoneVerified);
}
