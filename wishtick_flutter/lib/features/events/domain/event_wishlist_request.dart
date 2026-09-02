import 'package:flutter/foundation.dart';

/// Where a guest's offer of their own wishlist has got to.
enum EventWishlistRequestStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),

  /// Taken back down after approval — by the host, or withdrawn by the owner.
  removed('removed');

  const EventWishlistRequestStatus(this.wireValue);

  final String wireValue;

  static EventWishlistRequestStatus fromWire(String? value) =>
      EventWishlistRequestStatus.values.firstWhere(
        (v) => v.wireValue == value,
        orElse: () => pending,
      );

  bool get isPending => this == pending;
  bool get isApproved => this == approved;
}

/// A guest offering one of their own wishlists to an event they are going to.
///
/// The host has to approve it before it appears on the invitation, so the offer
/// exists as its own thing rather than as a flag on the list: a turned-down
/// offer must leave no mark on somebody's wishlist.
@immutable
class EventWishlistRequest {
  const EventWishlistRequest({
    required this.id,
    required this.eventId,
    required this.wishlistId,
    required this.wishlistTitle,
    required this.itemCount,
    required this.requestedById,
    required this.requestedByName,
    required this.status,
    required this.createdAt,
  });

  factory EventWishlistRequest.fromJson(Map<String, dynamic> json) =>
      EventWishlistRequest(
        id: json['id'] as String,
        eventId: json['eventId'] as String? ?? '',
        wishlistId: json['wishlistId'] as String? ?? '',
        wishlistTitle: json['wishlistTitle'] as String? ?? 'A wishlist',
        itemCount: json['itemCount'] as int? ?? 0,
        requestedById: json['requestedById'] as String? ?? '',
        requestedByName: json['requestedByName'] as String? ?? 'A friend',
        status: EventWishlistRequestStatus.fromWire(json['status'] as String?),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String eventId;
  final String wishlistId;
  final String wishlistTitle;

  /// How many items are on it — the host is deciding whether to show it.
  final int itemCount;
  final String requestedById;
  final String requestedByName;
  final EventWishlistRequestStatus status;
  final DateTime createdAt;

  /// "4 gifts" / "1 gift", or null when the list is empty — a host reading
  /// "0 gifts" learns nothing they could not see from a blank row.
  String? get itemLine => switch (itemCount) {
    0 => null,
    1 => '1 gift',
    _ => '$itemCount gifts',
  };
}
