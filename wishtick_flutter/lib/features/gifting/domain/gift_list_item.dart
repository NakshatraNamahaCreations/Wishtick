import 'package:flutter/foundation.dart';

import 'gift.dart';

/// One card in Gifts Received / Given / On Hold (`324:1108`, `324:1253`,
/// `324:1210`).
///
/// A different shape from [Gift]: the transactional views answer "what is the
/// state of this gift", and these cards answer "what does this row look like" —
/// the item's photo, title and price, the other person's first name, and
/// whether a thank-you has gone. The server joins all of that so a list of
/// twenty rows is one request, not eighty.
@immutable
class GiftListItem {
  const GiftListItem({
    required this.id,
    required this.itemId,
    required this.wishlistId,
    required this.status,
    required this.mode,
    required this.isGroup,
    required this.title,
    required this.imageUrl,
    required this.amountMinor,
    required this.currency,
    required this.counterpartyName,
    required this.deliveredAt,
    required this.expiresAt,
    required this.thankYouSent,
    required this.createdAt,
  });

  final String id;
  final String itemId;
  final String wishlistId;
  final GiftStatus status;
  final GiftMode mode;

  /// True for a group gift — what the Group tab filters on.
  final bool isGroup;

  final String title;
  final String? imageUrl;
  final int? amountMinor;
  final String currency;

  /// The other person's **first name only** — "For Rohan", "From Siya". Null
  /// when there is nobody to name.
  ///
  /// The server never sends an id here, on either side.
  final String? counterpartyName;

  final DateTime? deliveredAt;

  /// When an unpurchased reservation is released; what the On Hold card counts
  /// down to.
  final DateTime? expiresAt;
  final bool thankYouSent;
  final DateTime createdAt;

  bool get isDelivered => deliveredAt != null;

  /// Whether the gift is actually in the recipient's hands.
  ///
  /// An offline gift never gets an order, so it has no `deliveredAt` — for
  /// those the status is the only evidence. This is what gates the thank-you:
  /// the server drafts a note when a gift is *fulfilled*, so anything earlier
  /// has nothing to thank for.
  bool get hasArrived =>
      isDelivered ||
      status == GiftStatus.fulfilled ||
      status == GiftStatus.completed;

  /// How long is left on the hold; null when there is no expiry.
  Duration? timeLeft({DateTime? now}) {
    final end = expiresAt;
    if (end == null) return null;
    final remaining = end.difference(now ?? DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Re-shapes a [Gift] the transition endpoints returned into a list row.
  ///
  /// Exists because one screen — the item page — holds a single "your gift on
  /// this item", finds it in the on-hold *list* but updates it through
  /// reserve/purchase/cancel, which answer the transactional [Gift]. Rather
  /// than carry both shapes, the transactional answer is folded into the list
  /// shape using the item the screen already has open, which is the same item
  /// the server would have joined.
  factory GiftListItem.fromGift(
    Gift gift, {
    required String title,
    String? imageUrl,
    bool isGroup = false,
    String? counterpartyName,
  }) => GiftListItem(
    id: gift.id,
    itemId: gift.itemId,
    wishlistId: gift.wishlistId,
    status: gift.status,
    mode: gift.mode,
    isGroup: isGroup,
    title: title,
    imageUrl: imageUrl,
    amountMinor: gift.amountMinor,
    currency: gift.currency,
    counterpartyName: counterpartyName,
    // Neither is knowable from a transition response, and no caller of this
    // factory reads them — the item page shows a hold, not a delivery.
    deliveredAt: null,
    thankYouSent: false,
    expiresAt: gift.expiresAt,
    createdAt: gift.createdAt,
  );

  factory GiftListItem.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>? ?? const {};
    return GiftListItem(
      id: json['id'] as String,
      itemId: json['itemId'] as String,
      wishlistId: json['wishlistId'] as String,
      status: GiftStatus.fromWire(json['status'] as String?),
      mode: GiftMode.fromWire(json['mode'] as String?),
      isGroup: json['isGroup'] as bool? ?? false,
      title: item['title'] as String? ?? '',
      imageUrl: item['imageUrl'] as String?,
      amountMinor: item['amountMinor'] as int?,
      currency: item['currency'] as String? ?? 'INR',
      counterpartyName: json['counterpartyName'] as String?,
      deliveredAt: json['deliveredAt'] == null
          ? null
          : DateTime.parse(json['deliveredAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      thankYouSent: json['thankYouSent'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// The All / Individual / Group tabs each of the three list screens carries.
enum GiftListFilter {
  all('All'),
  individual('Individual'),
  group('Group');

  const GiftListFilter(this.label);

  final String label;

  bool matches(GiftListItem row) => switch (this) {
    all => true,
    individual => !row.isGroup,
    group => row.isGroup,
  };
}
