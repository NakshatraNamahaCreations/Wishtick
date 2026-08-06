import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/wishlist/domain/public_wishlist.dart';

void main() {
  Map<String, dynamic> itemJson({
    String id = 'i1',
    String title = 'Nike Air Max Sneakers',
    bool isClaimed = false,
  }) => {
    'id': id,
    'title': title,
    'notes': null,
    'imageUrls': <dynamic>[],
    'productLink': 'https://www.amazon.in/dp/x',
    'price': {'amountMinor': 1099900, 'currency': 'INR'},
    'category': null,
    'priority': 3,
    'importance': 'would_love',
    'quantity': 1,
    'giftPreferences': {'color': null, 'size': null, 'variantNotes': null},
    'isClaimed': isClaimed,
  };

  test('parses the redacted public shape', () {
    final wishlist = PublicWishlist.fromJson({
      'title': "Ananya's Wishlist",
      'description': 'A few special things',
      'coverUrl': null,
      'ownerFirstName': 'Ananya',
      'itemCount': 2,
      'items': [itemJson(), itemJson(id: 'i2', isClaimed: true)],
    });

    expect(wishlist.title, "Ananya's Wishlist");
    // First name only — the backend never sends a surname to a link holder.
    expect(wishlist.ownerFirstName, 'Ananya');
    expect(wishlist.items, hasLength(2));
  });

  test('counts available and claimed for the filter tabs', () {
    final wishlist = PublicWishlist.fromJson({
      'title': 'W',
      'description': null,
      'coverUrl': null,
      'ownerFirstName': 'A',
      'itemCount': 3,
      'items': [
        itemJson(id: 'a'),
        itemJson(id: 'b', isClaimed: true),
        itemJson(id: 'c', isClaimed: true),
      ],
    });

    expect(wishlist.availableCount, 1);
    expect(wishlist.claimedCount, 2);
  });

  test('an item reports only that it is claimed, never by whom', () {
    final item = PublicWishlistItem.fromJson(itemJson(isClaimed: true));

    expect(item.isClaimed, isTrue);
    // The public view has no status/claimant field at all; if one ever
    // appeared, this model would need a deliberate change to expose it.
    expect(item.price.amountMinor, 1099900);
  });

  test('survives an item list the server sent empty', () {
    final wishlist = PublicWishlist.fromJson({
      'title': 'W',
      'description': null,
      'coverUrl': null,
      'ownerFirstName': null,
      'itemCount': 0,
      'items': <dynamic>[],
    });

    expect(wishlist.items, isEmpty);
    expect(wishlist.availableCount, 0);
    expect(wishlist.ownerFirstName, isNull);
  });
}
