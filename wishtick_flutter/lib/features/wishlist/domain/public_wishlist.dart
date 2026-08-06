import 'package:flutter/foundation.dart';

import 'wishlist_item.dart';

/// One item on a shared wishlist (`PublicItemView`).
///
/// Deliberately smaller than [WishlistItem]: the backend redacts by explicit
/// allowlist, so a link holder learns *that* something is claimed but never
/// who claimed it, nor the granular status behind it.
@immutable
class PublicWishlistItem {
  const PublicWishlistItem({
    required this.id,
    required this.title,
    required this.notes,
    required this.imageUrls,
    required this.productLink,
    required this.price,
    required this.category,
    required this.priority,
    required this.importance,
    required this.quantity,
    required this.giftPreferences,
    required this.isClaimed,
  });

  final String id;
  final String title;
  final String? notes;
  final List<String> imageUrls;
  final String? productLink;
  final ItemPrice price;
  final String? category;

  /// 1 = highest.
  final int priority;

  final ItemImportance importance;
  final int quantity;
  final GiftPreferences giftPreferences;

  /// True once someone has reserved or bought it. The backend never says who.
  final bool isClaimed;

  String? get coverImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  factory PublicWishlistItem.fromJson(Map<String, dynamic> json) =>
      PublicWishlistItem(
        id: json['id'] as String,
        title: json['title'] as String,
        notes: json['notes'] as String?,
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
        isClaimed: json['isClaimed'] as bool? ?? false,
      );
}

/// A wishlist opened through its share link (`GET /public/wishlists/:slug`).
///
/// Carries no id, visibility, or access decision — a link holder is not a
/// participant, and the owner is named by first name only.
@immutable
class PublicWishlist {
  const PublicWishlist({
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.ownerFirstName,
    required this.itemCount,
    required this.items,
  });

  final String title;
  final String? description;
  final String? coverUrl;
  final String? ownerFirstName;
  final int itemCount;
  final List<PublicWishlistItem> items;

  int get availableCount => items.where((i) => !i.isClaimed).length;
  int get claimedCount => items.where((i) => i.isClaimed).length;

  factory PublicWishlist.fromJson(Map<String, dynamic> json) => PublicWishlist(
    title: json['title'] as String,
    description: json['description'] as String?,
    coverUrl: json['coverUrl'] as String?,
    ownerFirstName: json['ownerFirstName'] as String?,
    itemCount: json['itemCount'] as int? ?? 0,
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((e) => PublicWishlistItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
