import 'package:flutter/foundation.dart';

/// Who may see a wishlist and how — mirrors the backend's `WishlistVisibility`
/// enum exactly, wire values included.
enum WishlistVisibility {
  public('public'),
  private('private'),
  eventOnly('event_only'),
  inviteOnly('invite_only');

  const WishlistVisibility(this.wireValue);

  final String wireValue;

  static WishlistVisibility fromWire(String value) => WishlistVisibility.values
      .firstWhere((v) => v.wireValue == value, orElse: () => private);
}

/// What each visibility means to a person, and — the part that is easy to get
/// wrong — whether a share link actually opens the list.
///
/// Mirrors the backend's access matrix (`AccessPolicyService`): a link holder
/// is granted **nothing** on a `private` or `event_only` list, so handing
/// someone that link gives them a page they will be refused. Only
/// participants, and event invitees for `event_only`, get in.
extension WishlistVisibilityMeaning on WishlistVisibility {
  String get label => switch (this) {
    WishlistVisibility.public => 'Public',
    WishlistVisibility.private => 'Private',
    WishlistVisibility.eventOnly => 'Event only',
    WishlistVisibility.inviteOnly => 'Invite only',
  };

  String get summary => switch (this) {
    WishlistVisibility.public => 'Anyone with the link can view it.',
    WishlistVisibility.private => 'Only people you invite can view it.',
    WishlistVisibility.eventOnly => 'Only people invited to the event can '
        'view it.',
    WishlistVisibility.inviteOnly => 'Unlisted — anyone you send the link to '
        'can view it.',
  };

  /// Whether sending someone the share link is enough to let them in.
  bool get linkGrantsAccess =>
      this == WishlistVisibility.public ||
      this == WishlistVisibility.inviteOnly;
}

/// What the *current* caller may do with this wishlist — the backend always
/// computes and sends this, so the app renders permissions from here, never
/// by re-deriving them from `role`.
@immutable
class AccessDecision {
  const AccessDecision({
    required this.canView,
    required this.canComment,
    required this.canGift,
    required this.canManage,
    required this.relationship,
    required this.role,
  });

  final bool canView;
  final bool canComment;
  final bool canGift;
  final bool canManage;

  /// `owner` | `participant` | `event_participant` | `link_holder` | `public` | `none`.
  final String relationship;

  /// `viewer` | `contributor` | `moderator`, or null when [relationship]
  /// carries no participant role (e.g. the owner, or a stranger).
  final String? role;

  factory AccessDecision.fromJson(Map<String, dynamic> json) => AccessDecision(
    canView: json['canView'] as bool? ?? false,
    canComment: json['canComment'] as bool? ?? false,
    canGift: json['canGift'] as bool? ?? false,
    canManage: json['canManage'] as bool? ?? false,
    relationship: json['relationship'] as String? ?? 'none',
    role: json['role'] as String?,
  );
}

/// The owner-only share link — absent entirely (not just null) for anyone
/// else, so [Wishlist.share] itself is nullable rather than this being a
/// carrier of "no share exists".
@immutable
class ShareInfo {
  const ShareInfo({
    required this.slug,
    required this.url,
    required this.hasPasscode,
    required this.expiresAt,
  });

  final String slug;
  final String url;
  final bool hasPasscode;
  final DateTime? expiresAt;

  factory ShareInfo.fromJson(Map<String, dynamic> json) => ShareInfo(
    slug: json['slug'] as String,
    url: json['url'] as String,
    hasPasscode: json['hasPasscode'] as bool? ?? false,
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt'] as String),
  );
}

/// One wishlist, as returned by `GET/POST/PATCH /wishlists*` (`WishlistView`).
@immutable
class Wishlist {
  const Wishlist({
    required this.id,
    required this.title,
    required this.description,
    required this.visibility,
    required this.coverUrl,
    required this.occasionLabel,
    required this.chatEnabled,
    required this.eventId,
    required this.itemCount,
    required this.fulfilledCount,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.access,
    this.share,
  });

  final String id;
  final String title;
  final String? description;
  final WishlistVisibility visibility;
  final String? coverUrl;

  /// Free text, e.g. "Ananya's Birthday" — display context only, never
  /// validated against the occasion taxonomy (unlike an item's `occasionKey`).
  final String? occasionLabel;

  final bool chatEnabled;
  final String? eventId;
  final int itemCount;
  final int fulfilledCount;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AccessDecision access;

  /// Present only when the caller owns this wishlist.
  final ShareInfo? share;

  bool get isArchived => archivedAt != null;

  factory Wishlist.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    return Wishlist(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      visibility: WishlistVisibility.fromWire(json['visibility'] as String),
      coverUrl: json['coverUrl'] as String?,
      occasionLabel: json['occasionLabel'] as String?,
      chatEnabled: json['chatEnabled'] as bool? ?? true,
      eventId: json['eventId'] as String?,
      itemCount: stats['itemCount'] as int? ?? 0,
      fulfilledCount: stats['fulfilledCount'] as int? ?? 0,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      access: AccessDecision.fromJson(
        json['access'] as Map<String, dynamic>? ?? const {},
      ),
      share: json['share'] == null
          ? null
          : ShareInfo.fromJson(json['share'] as Map<String, dynamic>),
    );
  }
}
