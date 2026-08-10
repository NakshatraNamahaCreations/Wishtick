import 'package:flutter/foundation.dart';

/// Which way the money moves.
///
/// Wishtick holds none of it: a settlement is a *record* of a person-to-person
/// payment made outside the app (`4099:976` — "You are sending refund of ₹333
/// to each contributor **outside Wishtick**").
enum SettlementDirection {
  /// Host owes contributors — the group over-collected.
  returnToContributors('return'),

  /// Contributors owe the host — the price moved and the group is short.
  topUp('top_up');

  const SettlementDirection(this.wireValue);

  final String wireValue;

  static SettlementDirection? fromWire(String? value) {
    if (value == null) return null;
    for (final v in SettlementDirection.values) {
      if (v.wireValue == value) return v;
    }
    return null;
  }
}

/// Where a single settlement row has got to.
///
/// [sent] and [confirmed] are deliberately separate: `sent` is the payer's
/// claim, `confirmed` is the receiver's acknowledgement, and only the receiver
/// can close a row. One person cannot mark their own debt settled.
enum SettlementStatus {
  pending('pending'),
  sent('sent'),
  confirmed('confirmed'),
  cancelled('cancelled');

  const SettlementStatus(this.wireValue);

  final String wireValue;

  static SettlementStatus fromWire(String? value) => SettlementStatus.values
      .firstWhere((v) => v.wireValue == value, orElse: () => pending);

  /// Still owing — the row belongs on the "to settle" list.
  bool get isOpen => this == pending || this == sent;
}

/// One row of the settle-up ledger.
@immutable
class Settlement {
  const Settlement({
    required this.id,
    required this.groupGiftId,
    required this.contributorId,
    required this.hostId,
    required this.direction,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.upiId,
    this.sentAt,
    this.confirmedAt,
    this.note,
  });

  final String id;
  final String groupGiftId;
  final String contributorId;
  final String hostId;
  final SettlementDirection direction;
  final int amountMinor;
  final String currency;
  final SettlementStatus status;

  /// Where the payer should send it. A snapshot taken when the row was raised,
  /// so editing a profile later cannot silently redirect a payment already in
  /// flight. Null until the receiver has shared one.
  final String? upiId;

  final DateTime? sentAt;
  final DateTime? confirmedAt;
  final String? note;
  final DateTime createdAt;

  /// Who pays whom, for the current user.
  ///
  /// A settlement has two sides and each sees a different screen, so the
  /// direction alone is not enough to decide which — [userId] is.
  bool amPayer(String userId) => switch (direction) {
    SettlementDirection.returnToContributors => userId == hostId,
    SettlementDirection.topUp => userId == contributorId,
  };

  /// The counterpart's id — who to pay, or who to expect payment from.
  String counterpartId(String userId) =>
      userId == hostId ? contributorId : hostId;

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
    id: json['id'] as String,
    groupGiftId: json['groupGiftId'] as String,
    contributorId: json['contributorId'] as String,
    hostId: json['hostId'] as String,
    direction:
        SettlementDirection.fromWire(json['direction'] as String?) ??
        SettlementDirection.returnToContributors,
    amountMinor: json['amountMinor'] as int? ?? 0,
    currency: json['currency'] as String? ?? 'INR',
    status: SettlementStatus.fromWire(json['status'] as String?),
    upiId: json['upiId'] as String?,
    sentAt: json['sentAt'] == null
        ? null
        : DateTime.parse(json['sentAt'] as String),
    confirmedAt: json['confirmedAt'] == null
        ? null
        : DateTime.parse(json['confirmedAt'] as String),
    note: json['note'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// What the group owes, or is owed, once every cost is counted.
@immutable
class GroupGiftBalance {
  const GroupGiftBalance({
    required this.totalCostMinor,
    required this.pledgedMinor,
    required this.collectedMinor,
    required this.differenceMinor,
    required this.contributorCount,
    this.direction,
  });

  /// The Grand Total: every gift plus every charge.
  final int totalCostMinor;

  /// Everything promised, acknowledged or not.
  final int pledgedMinor;

  /// Only what the host has acknowledged receiving. The balance is measured
  /// against this rather than [pledgedMinor] — a host cannot hand back money
  /// nobody has actually given them.
  final int collectedMinor;

  /// `collected − totalCost`. Positive is a surplus the host owes back;
  /// negative is a shortfall the group owes. Zero means square.
  final int differenceMinor;

  /// Null when the group is exactly square.
  final SettlementDirection? direction;

  final int contributorCount;

  bool get isSquare => differenceMinor == 0;

  /// Always positive — the amount to move, whichever way it goes.
  int get absoluteDifferenceMinor => differenceMinor.abs();

  factory GroupGiftBalance.fromJson(Map<String, dynamic> json) =>
      GroupGiftBalance(
        totalCostMinor: json['totalCostMinor'] as int? ?? 0,
        pledgedMinor: json['pledgedMinor'] as int? ?? 0,
        collectedMinor: json['collectedMinor'] as int? ?? 0,
        differenceMinor: json['differenceMinor'] as int? ?? 0,
        direction: SettlementDirection.fromWire(json['direction'] as String?),
        contributorCount: json['contributorCount'] as int? ?? 0,
      );
}
