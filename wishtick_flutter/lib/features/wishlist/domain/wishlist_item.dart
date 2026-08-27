import 'package:flutter/foundation.dart';

/// Where an item stands in the gifting lifecycle — mirrors the backend's
/// `WishlistItemStatus` enum exactly.
enum WishlistItemStatus {
  available('available'),
  reserved('reserved'),
  purchased('purchased'),
  fulfilled('fulfilled'),
  giftedOffline('gifted_offline'),
  completed('completed');

  const WishlistItemStatus(this.wireValue);

  final String wireValue;

  static WishlistItemStatus fromWire(String value) => WishlistItemStatus.values
      .firstWhere((v) => v.wireValue == value, orElse: () => available);

  /// The backend never lets an item's substance change once it reaches one
  /// of these — matches `CLAIMED_ITEM_STATUSES` server-side.
  bool get isClaimed => this != available;
}

enum ItemImportance {
  niceToHave('nice_to_have'),
  wouldLove('would_love'),
  mustHave('must_have');

  const ItemImportance(this.wireValue);

  final String wireValue;

  static ItemImportance fromWire(String? value) => ItemImportance.values
      .firstWhere((v) => v.wireValue == value, orElse: () => wouldLove);
}

/// Minor-unit money (paise), never a float — matches the backend's own
/// reasoning: 0.1 + 0.2 != 0.3 in binary floating point.
@immutable
class ItemPrice {
  const ItemPrice({required this.amountMinor, required this.currency});

  final int? amountMinor;
  final String currency;

  /// Null when there is no price to show at all.
  double? get amount => amountMinor == null ? null : amountMinor! / 100;

  factory ItemPrice.fromJson(Map<String, dynamic> json) => ItemPrice(
    amountMinor: json['amountMinor'] as int?,
    currency: json['currency'] as String? ?? 'INR',
  );
}

@immutable
class GiftPreferences {
  const GiftPreferences({this.color, this.size, this.variantNotes});

  final String? color;
  final String? size;
  final String? variantNotes;

  bool get isEmpty => color == null && size == null && variantNotes == null;

  factory GiftPreferences.fromJson(Map<String, dynamic> json) =>
      GiftPreferences(
        color: json['color'] as String?,
        size: json['size'] as String?,
        variantNotes: json['variantNotes'] as String?,
      );
}

/// One entry on a wishlist (`ItemView`).
@immutable
class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.title,
    required this.notes,
    required this.recipientName,
    required this.relation,
    required this.occasionKey,
    required this.imageUrls,
    required this.productLink,
    required this.price,
    required this.category,
    required this.priority,
    required this.importance,
    required this.quantity,
    required this.giftPreferences,
    required this.status,
    required this.position,
    required this.createdAt,
    this.sourceProductId,
  });

  final String id;
  final String title;
  final String? notes;

  /// Who this gift is for — free text, display only.
  final String? recipientName;

  /// Free text, mirrors `/me/important-dates`' relation field.
  final String? relation;

  /// An occasion taxonomy key — same taxonomy as important dates.
  final String? occasionKey;

  final List<String> imageUrls;
  final String? productLink;
  final ItemPrice price;
  final String? category;

  /// 1 = highest priority.
  final int priority;

  final ItemImportance importance;
  final int quantity;
  final GiftPreferences giftPreferences;
  final WishlistItemStatus status;
  final int position;
  final DateTime createdAt;

  /// The catalogue row this was imported from; null when added by hand.
  ///
  /// The item's own title, price and image are a snapshot frozen at import.
  /// This is the handle for the things a snapshot never carried — the seller,
  /// the rating, the other sellers, the specification table — fetched through
  /// `GET /products/id/:productId`.
  final String? sourceProductId;

  /// Whether the catalogue can be asked for more than the snapshot holds.
  bool get hasCatalogueSource => sourceProductId != null;

  String? get coverImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
    id: json['id'] as String,
    title: json['title'] as String,
    notes: json['notes'] as String?,
    recipientName: json['recipientName'] as String?,
    relation: json['relation'] as String?,
    occasionKey: json['occasionKey'] as String?,
    imageUrls: (json['imageUrls'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    productLink: json['productLink'] as String?,
    price: ItemPrice.fromJson(
      json['price'] as Map<String, dynamic>? ?? const {},
    ),
    category: json['category'] as String?,
    priority: json['priority'] as int? ?? 3,
    importance: ItemImportance.fromWire(json['importance'] as String?),
    quantity: json['quantity'] as int? ?? 1,
    giftPreferences: GiftPreferences.fromJson(
      json['giftPreferences'] as Map<String, dynamic>? ?? const {},
    ),
    status: WishlistItemStatus.fromWire(json['status'] as String),
    position: json['position'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    sourceProductId: json['sourceProductId'] as String?,
  );
}
