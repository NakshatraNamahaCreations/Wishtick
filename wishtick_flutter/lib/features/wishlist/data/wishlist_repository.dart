import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/public_wishlist.dart';
import '../domain/wishlist.dart';
import '../domain/wishlist_item.dart';
import '../domain/wishlist_participant.dart';

/// Talks to the backend's `wishlists` module — lists, items, reorder, and the
/// owner's share link.
class WishlistRepository {
  WishlistRepository(this._api);

  final ApiClient _api;

  // ── Wishlists ───────────────────────────────────────────────────────────

  Future<List<Wishlist>> listMine({bool includeArchived = false}) async {
    final json = await _api.get<List<dynamic>>(
      '/wishlists',
      query: {'includeArchived': includeArchived.toString()},
    );
    return json
        .map((e) => Wishlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Wishlist> getOne(String id) async {
    final json = await _api.get<Map<String, dynamic>>('/wishlists/$id');
    return Wishlist.fromJson(json);
  }

  Future<Wishlist> create({
    required String title,
    String? description,
    String? occasionLabel,
    WishlistVisibility visibility = WishlistVisibility.private,
    String? coverMediaId,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/wishlists',
      body: {
        'title': title,
        'description': ?description,
        'occasionLabel': ?occasionLabel,
        'visibility': visibility.wireValue,
        'coverMediaId': ?coverMediaId,
      },
    );
    return Wishlist.fromJson(json);
  }

  Future<Wishlist> update(
    String id, {
    String? title,
    String? description,
    String? occasionLabel,
    WishlistVisibility? visibility,
    String? coverMediaId,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/wishlists/$id',
      body: {
        'title': ?title,
        'description': ?description,
        'occasionLabel': ?occasionLabel,
        'visibility': ?visibility?.wireValue,
        'coverMediaId': ?coverMediaId,
      },
    );
    return Wishlist.fromJson(json);
  }

  Future<void> archive(String id) => _api.delete<void>('/wishlists/$id');

  /// Wishlists other people have shared with the caller.
  Future<List<Wishlist>> listSharedWithMe() async {
    final json = await _api.get<List<dynamic>>('/wishlists/shared-with-me');
    return json
        .map((e) => Wishlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Sharing ─────────────────────────────────────────────────────────────

  /// Configures the share link. Passing nothing returns the current link
  /// unchanged, which is how the share sheet gets a URL for a list that has
  /// never been shared.
  ///
  /// [rotate] mints a new slug and invalidates every link already sent.
  Future<ShareInfo> configureShare(
    String id, {
    bool? rotate,
    String? passcode,
    bool clearPasscode = false,
    DateTime? expiresAt,
    bool clearExpiry = false,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/wishlists/$id/share',
      body: {
        'rotate': ?rotate,
        // `null` is meaningful here — it clears — so the two cases are
        // distinguished rather than collapsed by the null-omission syntax.
        if (clearPasscode) 'passcode': null else 'passcode': ?passcode,
        if (clearExpiry)
          'expiresAt': null
        else
          'expiresAt': ?expiresAt?.toIso8601String(),
      },
    );
    return ShareInfo.fromJson(json);
  }

  /// Opens a wishlist through its share link. Unauthenticated — a link holder
  /// is not a participant.
  Future<PublicWishlist> publicBySlug(String slug, {String? passcode}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/public/wishlists/$slug',
      query: {'passcode': ?passcode},
    );
    return PublicWishlist.fromJson(json);
  }

  // ── Participants ────────────────────────────────────────────────────────
  //
  // Who may open a wishlist that its share link does not admit. A private list
  // is *only* reachable this way — the access policy grants a link holder
  // nothing on one — so this is the invite mechanism, not an extra on top of
  // sharing.

  /// The guest list. Owner-only: the server refuses anyone else, because who
  /// was invited to a party is itself a thing worth keeping private.
  Future<List<WishlistParticipant>> listParticipants(String wishlistId) async {
    final json = await _api.get<List<dynamic>>(
      '/wishlists/$wishlistId/participants',
    );
    return json
        .map((e) => WishlistParticipant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Grants access, by [userId] for someone already on Wishtick or by
  /// The server answers 409 `PARTICIPANT_ALREADY_EXISTS` for a duplicate and
  /// 409 `CANNOT_INVITE_OWNER` for yourself.
  Future<WishlistParticipant> addParticipant(
    String wishlistId, {
    required String userId,
    ParticipantRole role = ParticipantRole.viewer,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/wishlists/$wishlistId/participants',
      body: {'userId': userId, 'role': role.wireValue},
    );
    return WishlistParticipant.fromJson(json);
  }

  /// Removes someone's access. Takes effect on their very next request — the
  /// access policy caches no decision.
  Future<void> revokeParticipant(String wishlistId, String participantId) =>
      _api.delete<void>('/wishlists/$wishlistId/participants/$participantId');

  // ── Items ───────────────────────────────────────────────────────────────

  Future<List<WishlistItem>> listItems(String wishlistId) async {
    final json = await _api.get<List<dynamic>>('/wishlists/$wishlistId/items');
    return json
        .map((e) => WishlistItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WishlistItem> getItem(String wishlistId, String itemId) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/wishlists/$wishlistId/items/$itemId',
    );
    return WishlistItem.fromJson(json);
  }

  Future<WishlistItem> addItem(
    String wishlistId, {
    required String title,
    String? notes,
    String? recipientName,
    String? relation,
    String? occasionKey,
    String? productLink,
    int? priceAmountMinor,
    String? category,
    int? priority,
    ItemImportance? importance,
    int? quantity,
    List<String>? mediaIds,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/wishlists/$wishlistId/items',
      body: {
        'title': title,
        'notes': ?notes,
        'recipientName': ?recipientName,
        'relation': ?relation,
        'occasionKey': ?occasionKey,
        'productLink': ?productLink,
        'price': ?(priceAmountMinor == null
            ? null
            : {'amountMinor': priceAmountMinor}),
        'category': ?category,
        'priority': ?priority,
        'importance': ?importance?.wireValue,
        'quantity': ?quantity,
        'mediaIds': ?mediaIds,
      },
    );
    return WishlistItem.fromJson(json);
  }

  /// Imports a catalogue product (known `provider`/`externalId`) — the
  /// backend snapshots its title/price/image/link onto the item right now;
  /// later upstream changes never mutate it. Lives on `ProductImportController`
  /// (`ProductsModule`, mounted under `/wishlists`) rather than
  /// `WishlistsController`, so the two modules don't import each other.
  Future<WishlistItem> addItemFromProduct(
    String wishlistId, {
    required String provider,
    required String externalId,
    String? notes,
    int? priority,
    int? quantity,
    String? recipientName,
    String? relation,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/wishlists/$wishlistId/items/from-product',
      body: {
        'provider': provider,
        'externalId': externalId,
        'notes': ?notes,
        'priority': ?priority,
        'quantity': ?quantity,
        // Set by "Gift Now", which saves to the buyer's own list on someone
        // else's behalf; a plain save leaves both off the body entirely.
        'recipientName': ?recipientName,
        'relation': ?relation,
      },
    );
    return WishlistItem.fromJson(json);
  }

  Future<WishlistItem> updateItem(
    String wishlistId,
    String itemId, {
    String? recipientName,
    String? relation,
    String? occasionKey,
    String? notes,
    int? priority,
    ItemImportance? importance,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/wishlists/$wishlistId/items/$itemId',
      body: {
        'recipientName': ?recipientName,
        'relation': ?relation,
        'occasionKey': ?occasionKey,
        'notes': ?notes,
        'priority': ?priority,
        'importance': ?importance?.wireValue,
      },
    );
    return WishlistItem.fromJson(json);
  }

  Future<void> removeItem(String wishlistId, String itemId) =>
      _api.delete<void>('/wishlists/$wishlistId/items/$itemId');

  Future<List<WishlistItem>> reorderItems(
    String wishlistId,
    List<String> itemIds,
  ) async {
    final json = await _api.patch<List<dynamic>>(
      '/wishlists/$wishlistId/items/reorder',
      body: {'itemIds': itemIds},
    );
    return json
        .map((e) => WishlistItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref.watch(apiClientProvider));
});
