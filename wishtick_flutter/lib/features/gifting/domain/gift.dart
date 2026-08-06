import 'package:flutter/foundation.dart';

/// Where a gift stands. Wire values mirror the backend's `GiftStatus`.
enum GiftStatus {
  reserved('reserved'),
  purchased('purchased'),
  fulfilled('fulfilled'),
  cancelled('cancelled'),
  completed('completed');

  const GiftStatus(this.wireValue);

  final String wireValue;

  static GiftStatus fromWire(String? value) => GiftStatus.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => reserved,
  );

  /// A gift in one of these no longer holds the item.
  bool get isActive => this != cancelled;
}

enum GiftMode {
  /// Bought through the affiliate flow; there is an order to follow.
  online('online'),

  /// Bought elsewhere. The backend deliberately mints no order for these.
  offline('offline');

  const GiftMode(this.wireValue);

  final String wireValue;

  static GiftMode fromWire(String? value) => GiftMode.values.firstWhere(
    (v) => v.wireValue == value,
    orElse: () => online,
  );
}

/// How long a reservation is expected to hold, for the one screen that has to
/// say so *before* a gift exists (the reserve confirmation sheet).
///
/// The server owns the real number — `RESERVATION_TTL_HOURS`, default 72 —
/// and every screen after the reservation reads [Gift.expiresAt] instead,
/// so this constant is only ever an up-front estimate. The Figma sheet shows
/// 48; changing the backend env to match is a one-line change if that is the
/// intent.
const kReservationHold = Duration(hours: 72);

/// One row of a gift's own history (`GiftView.history`).
///
/// The backend strips the `by` field before it leaves the server, so a
/// history row never names who acted — only what changed and when.
@immutable
class GiftHistoryEntry {
  const GiftHistoryEntry({
    required this.status,
    required this.at,
    required this.note,
  });

  final GiftStatus status;
  final DateTime at;
  final String? note;

  factory GiftHistoryEntry.fromJson(Map<String, dynamic> json) =>
      GiftHistoryEntry(
        status: GiftStatus.fromWire(json['status'] as String?),
        at: DateTime.parse(json['at'] as String),
        note: json['note'] as String?,
      );
}

/// A gift the caller is giving (`GiftView`).
///
/// Returned by reserve/purchase/fulfil and the `given` / `on-hold` lists. The
/// recipient's own view is a much smaller shape — see [ReceivedGift] — because
/// it must never reveal who is giving what.
@immutable
class Gift {
  const Gift({
    required this.id,
    required this.itemId,
    required this.wishlistId,
    required this.status,
    required this.mode,
    required this.amountMinor,
    required this.currency,
    required this.deliveryNotes,
    required this.reservedAt,
    required this.expiresAt,
    required this.createdAt,
    required this.history,
  });

  final String id;
  final String itemId;
  final String wishlistId;
  final GiftStatus status;
  final GiftMode mode;

  /// Snapshot of the item's price at reservation. Display only — no money
  /// moves through Wishtick.
  final int? amountMinor;
  final String currency;
  final String? deliveryNotes;
  final DateTime? reservedAt;

  /// When an unpurchased reservation is released. Null once purchased.
  final DateTime? expiresAt;
  final DateTime createdAt;
  final List<GiftHistoryEntry> history;

  /// How long is left on the hold; null when there is no expiry.
  Duration? timeLeft({DateTime? now}) {
    final end = expiresAt;
    if (end == null) return null;
    final remaining = end.difference(now ?? DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasExpired {
    final left = timeLeft();
    return left != null && left == Duration.zero;
  }

  /// Only an online gift has an order to follow.
  bool get isTrackable =>
      mode == GiftMode.online && status != GiftStatus.cancelled;

  factory Gift.fromJson(Map<String, dynamic> json) => Gift(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    wishlistId: json['wishlistId'] as String,
    status: GiftStatus.fromWire(json['status'] as String?),
    mode: GiftMode.fromWire(json['mode'] as String?),
    amountMinor: json['amountMinor'] as int?,
    currency: json['currency'] as String? ?? 'INR',
    deliveryNotes: json['deliveryNotes'] as String?,
    reservedAt: json['reservedAt'] == null
        ? null
        : DateTime.parse(json['reservedAt'] as String),
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    history: (json['history'] as List<dynamic>? ?? const [])
        .map((e) => GiftHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// A gift the caller is receiving (`RecipientGiftView`).
///
/// Deliberately tiny: no gifter, no history, no amount, no reservation timing.
/// The backend withholds all of it so a recipient cannot work out who is
/// giving them what before it arrives.
@immutable
class ReceivedGift {
  const ReceivedGift({
    required this.id,
    required this.itemId,
    required this.status,
    required this.mode,
    required this.createdAt,
  });

  final String id;
  final String itemId;
  final GiftStatus status;
  final GiftMode mode;
  final DateTime createdAt;

  factory ReceivedGift.fromJson(Map<String, dynamic> json) => ReceivedGift(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    status: GiftStatus.fromWire(json['status'] as String?),
    mode: GiftMode.fromWire(json['mode'] as String?),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
