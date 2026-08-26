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
  /// Legacy: an email invite nobody claimed. Nothing produces one now that
  /// sharing picks from WishMates, but old rows still deserialize.
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
/// Always an account: sharing picks from WishMates, so there is a [userId]
/// behind every row. [name] can still be null for somebody who signed up and
/// filled nothing in.
@immutable
class WishlistParticipant {
  const WishlistParticipant({
    required this.id,
    required this.userId,
    required this.name,
    required this.role,
    required this.state,
    required this.createdAt,
  });

  final String id;
  final String? userId;
  final String? name;
  final ParticipantRole role;
  final ParticipantState state;
  final DateTime createdAt;

  /// What to put on the row. A bare user id is not something to show anyone,
  /// so a nameless account gets a placeholder instead.
  String get displayName =>
      name?.trim().isNotEmpty ?? false ? name!.trim() : 'Someone on Wishtick';

  /// The line under [displayName]. Nothing to add now that the name is the
  /// account's own — kept so the row layout has one place to grow a handle.
  String? get subtitle => null;

  /// A legacy email invite still waiting for its owner to create an account.
  bool get isPending => state == ParticipantState.invited;

  factory WishlistParticipant.fromJson(Map<String, dynamic> json) =>
      WishlistParticipant(
        id: json['id'] as String,
        userId: json['userId'] as String?,
        name: json['name'] as String?,
        role: ParticipantRole.fromWire(json['role'] as String? ?? 'viewer'),
        state: ParticipantState.fromWire(
          json['state'] as String? ?? 'accepted',
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
