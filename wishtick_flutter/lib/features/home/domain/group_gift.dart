import 'package:flutter/foundation.dart';

enum GroupGiftStatus {
  open('open'),
  funded('funded'),
  purchasing('purchasing'),
  purchased('purchased'),
  fulfilled('fulfilled'),
  cancelled('cancelled'),
  refunding('refunding');

  const GroupGiftStatus(this.wireValue);

  final String wireValue;

  static GroupGiftStatus fromWire(String? value) => GroupGiftStatus.values
      .firstWhere((v) => v.wireValue == value, orElse: () => open);

  /// Only an open gift can still take money.
  bool get acceptsContributions => this == open;
}

/// A group gift the caller takes part in (`GET /group-gifts/mine`).
///
/// Home renders this read-only — the chip-in flow itself is Sprint 6. Only the
/// fields that card needs are modelled; the full view also carries a
/// participant list and contribution timeline.
@immutable
class GroupGift {
  const GroupGift({
    required this.id,
    required this.itemId,
    required this.wishlistId,
    required this.status,
    required this.targetAmountMinor,
    required this.collectedAmountMinor,
    required this.currency,
    required this.percentFunded,
    required this.contributorCount,
    required this.deadline,
    required this.myContributionMinor,
    this.message,
  });

  final String id;
  final String itemId;
  final String wishlistId;
  final GroupGiftStatus status;

  /// The goal, in minor units.
  final int targetAmountMinor;

  /// Raised so far, in minor units.
  final int collectedAmountMinor;
  final String currency;

  /// Server-computed and clamped 0..100 — not re-derived here, so the bar and
  /// the label can never disagree.
  final int percentFunded;

  final int contributorCount;
  final DateTime? deadline;
  final int myContributionMinor;
  final String? message;

  bool get hasContributed => myContributionMinor > 0;

  /// Whole days until the deadline; null when the gift has none.
  int? daysToDeadline({DateTime? now}) {
    final end = deadline;
    if (end == null) return null;
    final today = now ?? DateTime.now();
    return DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  factory GroupGift.fromJson(Map<String, dynamic> json) => GroupGift(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    wishlistId: json['wishlistId'] as String,
    status: GroupGiftStatus.fromWire(json['status'] as String?),
    targetAmountMinor: json['targetAmountMinor'] as int? ?? 0,
    collectedAmountMinor: json['collectedAmountMinor'] as int? ?? 0,
    currency: json['currency'] as String? ?? 'INR',
    percentFunded: json['percentFunded'] as int? ?? 0,
    contributorCount: json['contributorCount'] as int? ?? 0,
    deadline: json['deadline'] == null
        ? null
        : DateTime.parse(json['deadline'] as String),
    myContributionMinor: json['myContributionMinor'] as int? ?? 0,
    message: json['message'] as String?,
  );
}
