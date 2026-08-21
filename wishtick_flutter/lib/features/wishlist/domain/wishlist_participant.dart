import 'package:flutter/foundation.dart';

/// What an invited person may do — mirrors the backend's `ParticipantRole`,
/// wire values included.
enum ParticipantRole {
  /// Can see the list and gift from it, but not talk in its chat.
  viewer('viewer', 'Can view and gift'),

  /// Can also take part in the wishlist chat.
  contributor('contributor', 'Can view, gift and chat'),

  /// Contributor plus chat moderation. Still cannot edit the list — only the
  /// owner can, which is why this is not offered as a choice in the app.
  moderator('moderator', 'Can moderate the chat');

  const ParticipantRole(this.wireValue, this.description);

  final String wireValue;

  /// What granting this role actually allows, in the user's words.
  final String description;

  static ParticipantRole fromWire(String value) => ParticipantRole.values
      .firstWhere((r) => r.wireValue == value, orElse: () => viewer);
}

/// Where an invite has got to.
enum ParticipantState {
  /// Invited by email, no account claimed it yet.
  invited('invited'),
  accepted('accepted'),
  revoked('revoked');

  const ParticipantState(this.wireValue);

  final String wireValue;

  static ParticipantState fromWire(String value) => ParticipantState.values
      .firstWhere((s) => s.wireValue == value, orElse: () => accepted);
}

/// One person with access to a wishlist (`ParticipantView`).
///
/// Either [userId]/[name] or [inviteEmail] identifies them: an invite sent to
/// an address with no account yet has no user to name, and gets linked to one
/// when that person signs up.
@immutable
class WishlistParticipant {
  const WishlistParticipant({
    required this.id,
    required this.userId,
    required this.name,
    required this.inviteEmail,
    required this.role,
    required this.state,
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String? name;
  final String? inviteEmail;
  final ParticipantRole role;
  final ParticipantState state;
  final DateTime createdAt;

  /// What to put on the row. Falls back through name → email → a placeholder,
  /// because a bare user id is not something to show anyone.
  String get displayName => name?.trim().isNotEmpty ?? false
      ? name!.trim()
      : (inviteEmail ?? 'Someone on Wishtick');

  /// The line under [displayName], or null when it would just repeat it.
  String? get subtitle {
    final hasName = name?.trim().isNotEmpty ?? false;
    return hasName ? inviteEmail : null;
  }

  /// An email invite still waiting for its owner to create an account.
  bool get isPending => state == ParticipantState.invited;

  factory WishlistParticipant.fromJson(Map<String, dynamic> json) =>
      WishlistParticipant(
        id: json['id'] as String,
        userId: json['userId'] as String?,
        name: json['name'] as String?,
        inviteEmail: json['inviteEmail'] as String?,
        role: ParticipantRole.fromWire(json['role'] as String? ?? 'viewer'),
        state: ParticipantState.fromWire(
          json['state'] as String? ?? 'accepted',
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
