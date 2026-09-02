import 'package:image_picker/image_picker.dart';
import 'package:wishtick_flutter/core/media/media_repository.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/wishlist/data/product_repository.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/product.dart';
import 'package:wishtick_flutter/features/wishlist/domain/public_wishlist.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist_item.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist_participant.dart';

Wishlist buildWishlist({
  String id = 'wl_1',
  String title = 'Ananya\'s Wishlist',
  String? description = 'A few special things',
  WishlistVisibility visibility = WishlistVisibility.public,
  String? coverUrl,
  int itemCount = 0,
  int fulfilledCount = 0,
  bool chatEnabled = true,
  // Explicit null means the list has never been shared, so the share screen
  // has to mint a slug — which is the case worth distinguishing.
  ShareInfo? share = const ShareInfo(
    slug: 'share-slug',
    url: 'https://wishtick.dev/w/share-slug',
    hasPasscode: false,
    expiresAt: null,
  ),
  AccessDecision access = const AccessDecision(
    canView: true,
    canComment: true,
    canGift: false,
    canManage: true,
    relationship: 'owner',
    role: null,
  ),
}) {
  return Wishlist(
    id: id,
    title: title,
    description: description,
    visibility: visibility,
    coverUrl: coverUrl,
    occasionLabel: null,
    chatEnabled: chatEnabled,
    eventId: null,
    itemCount: itemCount,
    fulfilledCount: fulfilledCount,
    archivedAt: null,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
    access: access,
    share: share,
  );
}

WishlistItem buildItem({
  String id = 'item_1',
  String title = 'Nike Air Max Sneakers',
  String? recipientName,
  String? relation,
  String? occasionKey,
  String? productLink,
  int? amountMinor = 1099900,
  int position = 0,
  ItemImportance importance = ItemImportance.wouldLove,
  WishlistItemStatus status = WishlistItemStatus.available,
  List<String> imageUrls = const [],
  String? sourceProductId,
}) {
  return WishlistItem(
    id: id,
    title: title,
    notes: null,
    recipientName: recipientName,
    relation: relation,
    occasionKey: occasionKey,
    imageUrls: imageUrls,
    productLink: productLink,
    price: ItemPrice(amountMinor: amountMinor, currency: 'INR'),
    category: null,
    priority: 3,
    importance: importance,
    quantity: 1,
    giftPreferences: const GiftPreferences(),
    status: status,
    position: position,
    createdAt: DateTime(2026, 6, 1),
    sourceProductId: sourceProductId,
  );
}

/// Scriptable stand-in for the wishlists API — mirrors
/// `FakeOnboardingRepository`'s shape: configurable failures, captured calls.
class FakeWishlistRepository implements WishlistRepository {
  FakeWishlistRepository({List<Wishlist>? wishlists, List<WishlistItem>? items})
    : wishlists = wishlists ?? [],
      items = items ?? [];

  final List<Wishlist> wishlists;
  final List<WishlistItem> items;

  /// What `listSharedWithMe` returns; empty unless a test sets it.
  final List<Wishlist> sharedWithMe = [];

  /// What `publicBySlug` returns; throws unless a test sets it.
  PublicWishlist? publicWishlist;

  ApiException? failure;

  int listMineCalls = 0;
  final createCalls = <String>[];
  final createdForUserIds = <String?>[];
  final updateCalls = <String>[];
  final archiveCalls = <String>[];
  final addItemCalls = <String>[];

  /// Includes the recipient tag, which is the only thing that distinguishes a
  /// "Gift Now" save from a plain one.
  final addItemFromProductCalls =
      <(String provider, String externalId, String? recipientName)>[];
  final updateItemCalls = <String>[];
  final removeItemCalls = <String>[];
  final configureShareCalls = <(String id, bool rotate)>[];
  final publicBySlugCalls = <String>[];

  void _throwIfFailing() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<List<Wishlist>> listMine({bool includeArchived = false}) async {
    listMineCalls++;
    _throwIfFailing();
    return wishlists
        .where((w) => includeArchived || w.archivedAt == null)
        .toList();
  }

  @override
  Future<Wishlist> getOne(String id) async {
    _throwIfFailing();
    return wishlists.firstWhere((w) => w.id == id);
  }

  @override
  Future<Wishlist> create({
    required String title,
    String? description,
    String? occasionLabel,
    WishlistVisibility visibility = WishlistVisibility.private,
    String? coverMediaId,
    String? forUserId,
  }) async {
    createCalls.add(title);
    // Recorded rather than inferred: the person a list is *for* travels as an
    // id the built Wishlist would not otherwise carry.
    createdForUserIds.add(forUserId);
    _throwIfFailing();
    final created = buildWishlist(
      id: 'wl_${wishlists.length + 1}',
      title: title,
      description: description,
      visibility: visibility,
      coverUrl: coverMediaId,
    );
    wishlists.add(created);
    return created;
  }

  @override
  Future<Wishlist> update(
    String id, {
    String? title,
    String? description,
    String? occasionLabel,
    WishlistVisibility? visibility,
    String? coverMediaId,
    String? forUserId,
  }) async {
    updateCalls.add(id);
    _throwIfFailing();
    final index = wishlists.indexWhere((w) => w.id == id);
    final current = wishlists[index];
    final updated = buildWishlist(
      id: current.id,
      title: title ?? current.title,
      description: description ?? current.description,
      visibility: visibility ?? current.visibility,
      coverUrl: coverMediaId ?? current.coverUrl,
      itemCount: current.itemCount,
      fulfilledCount: current.fulfilledCount,
    );
    wishlists[index] = updated;
    return updated;
  }

  @override
  Future<void> archive(String id) async {
    archiveCalls.add(id);
    _throwIfFailing();
    final index = wishlists.indexWhere((w) => w.id == id);
    if (index != -1) {
      wishlists[index] = buildWishlist(
        id: wishlists[index].id,
        title: wishlists[index].title,
      );
    }
  }

  @override
  Future<List<WishlistItem>> listItems(String wishlistId) async {
    _throwIfFailing();
    return List.of(items);
  }

  @override
  Future<WishlistItem> getItem(String wishlistId, String itemId) async {
    _throwIfFailing();
    return items.firstWhere((i) => i.id == itemId);
  }

  @override
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
    addItemCalls.add(title);
    _throwIfFailing();
    final created = buildItem(
      id: 'item_${items.length + 1}',
      title: title,
      recipientName: recipientName,
      relation: relation,
      occasionKey: occasionKey,
      productLink: productLink,
      amountMinor: priceAmountMinor,
      position: items.length,
      importance: importance ?? ItemImportance.wouldLove,
    );
    items.add(created);
    return created;
  }

  @override
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
    addItemFromProductCalls.add((provider, externalId, recipientName));
    _throwIfFailing();
    final created = buildItem(
      id: 'item_${items.length + 1}',
      title: 'Imported product',
      position: items.length,
    );
    items.add(created);
    return created;
  }

  @override
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
    updateItemCalls.add(itemId);
    _throwIfFailing();
    final index = items.indexWhere((i) => i.id == itemId);
    final current = items[index];
    final updated = buildItem(
      id: current.id,
      title: current.title,
      recipientName: recipientName ?? current.recipientName,
      relation: relation ?? current.relation,
      occasionKey: occasionKey ?? current.occasionKey,
      productLink: current.productLink,
      amountMinor: current.price.amountMinor,
      position: current.position,
      importance: importance ?? current.importance,
      status: current.status,
    );
    items[index] = updated;
    return updated;
  }

  @override
  Future<void> removeItem(String wishlistId, String itemId) async {
    removeItemCalls.add(itemId);
    _throwIfFailing();
    items.removeWhere((i) => i.id == itemId);
  }

  @override
  Future<List<Wishlist>> listSharedWithMe() async {
    _throwIfFailing();
    return List.of(sharedWithMe);
  }

  @override
  Future<ShareInfo> configureShare(
    String id, {
    bool? rotate,
    String? passcode,
    bool clearPasscode = false,
    DateTime? expiresAt,
    bool clearExpiry = false,
  }) async {
    configureShareCalls.add((id, rotate ?? false));
    _throwIfFailing();
    final slug = rotate == true ? 'rotated-slug' : 'share-slug';
    return ShareInfo(
      slug: slug,
      url: 'https://wishtick.dev/w/$slug',
      hasPasscode: clearPasscode ? false : passcode != null,
      expiresAt: clearExpiry ? null : expiresAt,
    );
  }

  // ── Participants ──────────────────────────────────────────────────────────

  /// The guest list `listParticipants` returns; empty unless a test sets it.
  final List<WishlistParticipant> participants = [];

  final addParticipantCalls = <({String userId, ParticipantRole role})>[];
  final revokeParticipantCalls = <String>[];

  @override
  Future<List<WishlistParticipant>> listParticipants(String wishlistId) async {
    _throwIfFailing();
    return List.of(participants);
  }

  @override
  Future<WishlistParticipant> addParticipant(
    String wishlistId, {
    required String userId,
    ParticipantRole role = ParticipantRole.viewer,
  }) async {
    addParticipantCalls.add((userId: userId, role: role));
    _throwIfFailing();
    final added = WishlistParticipant(
      id: 'p_${participants.length + 1}',
      userId: userId,
      name: null,
      role: role,
      state: ParticipantState.accepted,
      createdAt: DateTime(2026, 6, 1),
    );
    participants.add(added);
    return added;
  }

  @override
  Future<void> revokeParticipant(
    String wishlistId,
    String participantId,
  ) async {
    revokeParticipantCalls.add(participantId);
    _throwIfFailing();
    participants.removeWhere((p) => p.id == participantId);
  }

  @override
  Future<PublicWishlist> publicBySlug(String slug, {String? passcode}) async {
    publicBySlugCalls.add(slug);
    _throwIfFailing();
    final source = publicWishlist;
    if (source == null) throw StateError('No public wishlist configured');
    return source;
  }

  @override
  Future<List<WishlistItem>> reorderItems(
    String wishlistId,
    List<String> itemIds,
  ) async {
    _throwIfFailing();
    for (var i = 0; i < items.length; i++) {
      final position = itemIds.indexOf(items[i].id);
      if (position != -1) {
        items[i] = buildItem(
          id: items[i].id,
          title: items[i].title,
          position: position,
          amountMinor: items[i].price.amountMinor,
        );
      }
    }
    items.sort((a, b) => a.position.compareTo(b.position));
    return List.of(items);
  }
}

/// Scriptable stand-in for the products API.
class FakeProductRepository implements ProductRepository {
  ApiException? searchFailure;
  ApiException? resolveFailure;
  ApiException? detailsFailure;
  ProductSearchResult? searchResult;
  ResolvedUrlProduct? resolveResult;

  /// What the detail lookup returns. Null leaves it unanswered, which is the
  /// "provider gave us nothing extra" case.
  NormalizedProduct? detailsResult;

  int searchCalls = 0;
  final resolveCalls = <String>[];
  final detailsCalls = <String>[];
  final detailsByIdCalls = <String>[];

  @override
  Future<NormalizedProduct> details({
    required String provider,
    required String externalId,
  }) async {
    detailsCalls.add('$provider/$externalId');
    final failure = detailsFailure;
    if (failure != null) throw failure;
    final result = detailsResult;
    if (result == null) {
      throw const ApiException(
        code: ApiException.codeUnknown,
        message: 'no details stubbed',
      );
    }
    return result;
  }

  @override
  Future<NormalizedProduct> detailsById(String productId) async {
    detailsByIdCalls.add(productId);
    final failure = detailsFailure;
    if (failure != null) throw failure;
    final result = detailsResult;
    if (result == null) {
      throw const ApiException(
        code: ApiException.codeUnknown,
        message: 'no details stubbed',
      );
    }
    return result;
  }

  @override
  Future<ProductSearchResult> search({
    String? query,
    String? category,
    int? minPriceMinor,
    int? maxPriceMinor,
    int page = 1,
    int pageSize = 20,
  }) async {
    searchCalls++;
    final failure = searchFailure;
    if (failure != null) throw failure;
    return searchResult ??
        const ProductSearchResult(
          items: [],
          page: 1,
          pageSize: 20,
          totalEstimate: 0,
          hasMore: false,
          freshness: ResultFreshness.live,
        );
  }

  @override
  Future<ResolvedUrlProduct> resolveUrl(String url) async {
    resolveCalls.add(url);
    final failure = resolveFailure;
    if (failure != null) throw failure;
    return resolveResult ??
        const ResolvedUrlProduct(
          fromKnownProvider: false,
          title: 'Resolved product',
          productUrl: 'https://example.com/p',
          description: null,
          imageUrls: [],
          amountMinor: null,
          currency: 'INR',
          provider: null,
          externalId: null,
        );
  }
}

/// Skips the real upload handshake — returns the picked file's own path.
class FakeMediaRepository implements MediaRepository {
  final uploadCalls = <MediaPurpose>[];

  @override
  Future<MediaView> uploadFile({
    required XFile file,
    required MediaPurpose purpose,
    String? fileName,
  }) async {
    uploadCalls.add(purpose);
    return MediaView(
      id: file.path,
      url: file.path,
      purpose: purpose.wireValue,
      contentType: null,
      sizeBytes: null,
    );
  }
}
