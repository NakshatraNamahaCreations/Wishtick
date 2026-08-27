import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/domain/onboarding_options.dart';
import '../../features/onboarding/domain/profile_draft.dart';
import '../../features/wishlist/data/product_repository.dart';
import '../../features/wishlist/data/wishlist_repository.dart';
import '../../features/wishlist/domain/product.dart';
import '../../features/wishlist/domain/public_wishlist.dart';
import '../../features/wishlist/domain/wishlist.dart';
import '../../features/wishlist/domain/wishlist_item.dart';
import '../../features/wishlist/domain/wishlist_participant.dart';
import '../media/media_repository.dart';
import '../network/token_storage.dart';
import 'dev_keys.dart';
import 'dev_taxonomy.dart';

/// Accepts any phone number and any correctly-sized code.
///
/// Real tokens are still written through [TokenStorage] by the session
/// controller, so sign-in survives a restart exactly as it will in production —
/// the only thing faked is the server's answer.
///
/// **Signing in always lands in signup/onboarding.** Unlike the real backend,
/// which knows a returning user, the fake treats every sign-in as a first one
/// so the whole signup path stays one tap away. A restart still resumes to
/// Home once onboarding has been finished — it is *logging in* that resets,
/// not relaunching.
class DevAuthRepository implements AuthRepository {
  DevAuthRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Enough delay to see the button's spinner; short enough not to annoy.
  static const _latency = Duration(milliseconds: 400);

  AuthUser _user() => AuthUser(
    id: 'dev-user',
    phone: _prefs.getString(DevKeys.phone) ?? '+910000000000',
    name: _prefs.getString(DevKeys.name),
    emailVerified: false,
    phoneVerified: true,
    roles: const ['user'],
    createdAt: DateTime.now(),
  );

  @override
  Future<OtpRequestResult> requestSignInCode(String phone) async {
    await Future<void>.delayed(_latency);
    await _prefs.setString(DevKeys.phone, phone);
    // No devCode: any correctly-sized code verifies here (see the class doc),
    // so there is no one true code to show.
    return const OtpRequestResult(validity: AuthRepository.otpValidity);
  }

  @override
  Future<AuthResult> verifySignInCode({
    required String phone,
    required String code,
    String? name,
  }) async {
    await Future<void>.delayed(_latency);
    await _prefs.setString(DevKeys.phone, phone);
    if (name != null) await _prefs.setString(DevKeys.name, name);

    // Every fake sign-in presents as a brand-new account, so signing in is
    // always a route into signup and onboarding. Otherwise the flow could only
    // be reached on a fresh install or after an explicit logout, which is the
    // opposite of what a fake backend is for.
    //
    // The stored flag is cleared as well as reporting `isNewUser`. The two
    // have to agree: the router takes `isNewUser` at its word, but the session
    // re-reads DevOnboardingRepository.status() on restore, and a stale "yes,
    // complete" there would bounce the user straight back out to Home.
    await _prefs.remove(DevKeys.onboardingComplete);

    return AuthResult(
      user: _user(),
      tokens: const AuthTokens(
        accessToken: 'dev-access',
        refreshToken: 'dev-refresh',
      ),
      isNewUser: true,
    );
  }

  @override
  Future<AuthUser> me() async {
    await Future<void>.delayed(_latency);
    return _user();
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(DevKeys.onboardingComplete);
    await _prefs.remove(DevKeys.dates);
  }

  // The password flow is not reachable from the UI; the fake refuses it rather
  // than pretending, so nobody builds on a path that does not exist.
  @override
  Future<AuthResult> signup({
    required String password,
    String? email,
    String? phone,
    String? name,
  }) => throw UnimplementedError('Password signup is not part of the dev flow');

  @override
  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) => throw UnimplementedError('Password login is not part of the dev flow');

  @override
  Future<void> requestPhoneVerification(String phone) async {}

  @override
  Future<void> confirmPhoneVerification({
    required String phone,
    required String code,
  }) async {}
}

/// Serves the real taxonomy shape from memory and accepts every step save.
class DevOnboardingRepository implements OnboardingRepository {
  DevOnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _latency = Duration(milliseconds: 300);

  bool get _complete => _prefs.getBool(DevKeys.onboardingComplete) ?? false;

  OnboardingStatus _status() => OnboardingStatus(
    completed: _complete,
    completedSteps: _complete ? const ['profile'] : const [],
    remainingRequiredSteps: _complete ? const [] : const ['profile'],
  );

  @override
  Future<OnboardingStatus> status() async {
    await Future<void>.delayed(_latency);
    return _status();
  }

  @override
  Future<OnboardingOptions> options() async {
    await Future<void>.delayed(_latency);
    return DevTaxonomy.build();
  }

  @override
  Future<OnboardingStatus> saveProfile(ProfileDraft draft) async {
    await Future<void>.delayed(_latency);
    if (draft.hasName) await _prefs.setString(DevKeys.name, draft.name.trim());
    return _status();
  }

  @override
  Future<OnboardingStatus> saveInterests({
    required List<String> interestCategories,
    required List<String> interests,
    required List<String> customInterests,
  }) async {
    await Future<void>.delayed(_latency);
    return _status();
  }

  @override
  Future<OnboardingStatus> saveColors(List<String> favouriteColors) async {
    await Future<void>.delayed(_latency);
    return _status();
  }

  @override
  Future<OnboardingStatus> saveSizes({
    String? clothingSize,
    String? shoeSize,
    String? fitPreference,
  }) async {
    await Future<void>.delayed(_latency);
    return _status();
  }

  @override
  Future<OnboardingStatus> complete() async {
    await Future<void>.delayed(_latency);
    await _prefs.setBool(DevKeys.onboardingComplete, true);
    return _status();
  }

  // ── Important dates, persisted as JSON rows ───────────────────────────────
  // JSON rather than a delimited string: names are free text and would break
  // any separator we picked.

  List<ImportantDate> _readDates() {
    return (_prefs.getStringList(DevKeys.dates) ?? const [])
        .map(
          (row) =>
              ImportantDate.fromJson(jsonDecode(row) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _writeDates(List<ImportantDate> dates) =>
      _prefs.setStringList(DevKeys.dates, [
        for (final d in dates)
          jsonEncode({
            'id': d.id,
            'personName': d.personName,
            'relation': d.relation,
            'occasionKey': d.occasionKey,
            'date': d.date,
          }),
      ]);

  @override
  Future<List<ImportantDate>> listImportantDates() async {
    await Future<void>.delayed(_latency);
    return _readDates();
  }

  @override
  Future<ImportantDate> addImportantDate({
    required String personName,
    required String relation,
    required String occasionKey,
    required String dateIso,
  }) async {
    await Future<void>.delayed(_latency);
    final dates = _readDates();
    final saved = ImportantDate(
      id: 'dev-${dates.length + 1}',
      personName: personName,
      relation: relation,
      occasionKey: occasionKey,
      date: dateIso,
    );
    await _writeDates([...dates, saved]);
    return saved;
  }

  @override
  Future<void> removeImportantDate(String id) async {
    await _writeDates(_readDates().where((d) => d.id != id).toList());
  }
}

/// Persists wishlists/items as JSON rows in [SharedPreferences], seeded once
/// on first run so the tab isn't empty, then mutable like a real backend.
///
/// `access`/`share` are computed on read rather than stored — there is only
/// ever one (owner) user in dev mode, so both are always the same shape.
class DevWishlistRepository implements WishlistRepository {
  DevWishlistRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _latency = Duration(milliseconds: 300);

  // Seeding needs to run once before any read, but a constructor can't be
  // async — so it's a memoized future, awaited at the top of every call.
  Future<void>? _seedFuture;
  Future<void> _ready() => _seedFuture ??= _seedIfNeeded();

  List<Map<String, dynamic>> _readWishlists() =>
      (jsonDecode(_prefs.getString(DevKeys.wishlists) ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> _writeWishlists(List<Map<String, dynamic>> rows) =>
      _prefs.setString(DevKeys.wishlists, jsonEncode(rows));

  List<Map<String, dynamic>> _readItems() =>
      (jsonDecode(_prefs.getString(DevKeys.wishlistItems) ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> _writeItems(List<Map<String, dynamic>> rows) =>
      _prefs.setString(DevKeys.wishlistItems, jsonEncode(rows));

  /// Seeds anything missing, rather than overwriting the store.
  ///
  /// [DevKeys.wishlistSeeded] is versioned, so bumping it re-runs this against
  /// a device that already has dev state — merging keeps whatever was created
  /// by hand there instead of throwing it away to add one fixture.
  Future<void> _seedIfNeeded() async {
    if (_prefs.getBool(DevKeys.wishlistSeeded) ?? false) return;

    final wishlists = _readWishlists();
    final haveWishlists = wishlists.map((r) => r['id']).toSet();
    await _writeWishlists([
      ...wishlists,
      ..._seedWishlists.where((r) => !haveWishlists.contains(r['id'])),
    ]);

    final items = _readItems();
    final haveItems = items.map((r) => r['id']).toSet();
    await _writeItems([
      ...items,
      ..._seedItems.where((r) => !haveItems.contains(r['id'])),
    ]);

    await _prefs.setBool(DevKeys.wishlistSeeded, true);
  }

  /// The one seeded list you do not own, so the gifting flow has a subject.
  static const _friendWishlistId = 'dev-wl-4';

  Wishlist _toWishlist(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> items,
  ) {
    final mine = items.where((i) => i['wishlistId'] == row['id']);
    final fulfilled = mine.where((i) => i['status'] != 'available').length;
    final theirs = row['sharedWithMe'] as bool? ?? false;
    return Wishlist.fromJson({
      ...row,
      'stats': {'itemCount': mine.length, 'fulfilledCount': fulfilled},
      // canGift and canManage are mutually exclusive here for the same reason
      // they are on the server: you cannot gift your own item.
      'access': {
        'canView': true,
        'canComment': true,
        'canGift': theirs,
        'canManage': !theirs,
        'relationship': theirs ? 'participant' : 'owner',
        'role': null,
      },
      'share': {
        'slug': 'dev-${row['id']}',
        'url': 'https://wishtick.dev/w/dev-${row['id']}',
        'hasPasscode': false,
        'expiresAt': null,
      },
    });
  }

  @override
  Future<List<Wishlist>> listMine({bool includeArchived = false}) async {
    await _ready();
    await Future<void>.delayed(_latency);
    final items = _readItems();
    return _readWishlists()
        .where((r) => includeArchived || r['archivedAt'] == null)
        .where((r) => r['sharedWithMe'] != true)
        .map((r) => _toWishlist(r, items))
        .toList();
  }

  @override
  Future<Wishlist> getOne(String id) async {
    await _ready();
    await Future<void>.delayed(_latency);
    final row = _readWishlists().firstWhere(
      (r) => r['id'] == id,
      orElse: () => throw StateError('Wishlist $id not found'),
    );
    return _toWishlist(row, _readItems());
  }

  @override
  Future<Wishlist> create({
    required String title,
    String? description,
    String? occasionLabel,
    WishlistVisibility visibility = WishlistVisibility.private,
    String? coverMediaId,
  }) async {
    await _ready();
    await Future<void>.delayed(_latency);
    final rows = _readWishlists();
    final now = DateTime.now().toIso8601String();
    // A media id IS a url in dev mode (see DevMediaRepository), so it can be
    // stored straight into coverUrl with no lookup step.
    final row = {
      'id': 'dev-wl-${DateTime.now().microsecondsSinceEpoch}',
      'title': title,
      'description': description,
      'occasionLabel': occasionLabel,
      'visibility': visibility.wireValue,
      'coverUrl': coverMediaId,
      'chatEnabled': true,
      'eventId': null,
      'archivedAt': null,
      'createdAt': now,
      'updatedAt': now,
    };
    await _writeWishlists([...rows, row]);
    return _toWishlist(row, _readItems());
  }

  @override
  Future<Wishlist> update(
    String id, {
    String? title,
    String? description,
    String? occasionLabel,
    WishlistVisibility? visibility,
    String? coverMediaId,
  }) async {
    await _ready();
    await Future<void>.delayed(_latency);
    final rows = _readWishlists();
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index == -1) throw StateError('Wishlist $id not found');
    final row = rows[index];
    if (title != null) row['title'] = title;
    if (description != null) row['description'] = description;
    if (occasionLabel != null) row['occasionLabel'] = occasionLabel;
    if (visibility != null) row['visibility'] = visibility.wireValue;
    if (coverMediaId != null) row['coverUrl'] = coverMediaId;
    row['updatedAt'] = DateTime.now().toIso8601String();
    await _writeWishlists(rows);
    return _toWishlist(row, _readItems());
  }

  @override
  Future<void> archive(String id) async {
    await _ready();
    final rows = _readWishlists();
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index == -1) return;
    rows[index]['archivedAt'] = DateTime.now().toIso8601String();
    await _writeWishlists(rows);
  }

  @override
  Future<List<WishlistItem>> listItems(String wishlistId) async {
    await _ready();
    await Future<void>.delayed(_latency);
    final rows =
        _readItems().where((i) => i['wishlistId'] == wishlistId).toList()..sort(
          (a, b) => (a['position'] as int).compareTo(b['position'] as int),
        );
    return rows.map(WishlistItem.fromJson).toList();
  }

  @override
  Future<WishlistItem> getItem(String wishlistId, String itemId) async {
    await _ready();
    await Future<void>.delayed(_latency);
    final row = _readItems().firstWhere(
      (i) => i['wishlistId'] == wishlistId && i['id'] == itemId,
      orElse: () => throw StateError('Item $itemId not found'),
    );
    return WishlistItem.fromJson(row);
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
    await _ready();
    await Future<void>.delayed(_latency);
    final items = _readItems();
    final position = items.where((i) => i['wishlistId'] == wishlistId).length;
    final row = {
      'id': 'dev-item-${DateTime.now().microsecondsSinceEpoch}',
      'wishlistId': wishlistId,
      'title': title,
      'notes': notes,
      'recipientName': recipientName,
      'relation': relation,
      'occasionKey': occasionKey,
      'imageUrls': mediaIds ?? const <String>[],
      'productLink': productLink,
      'price': {'amountMinor': priceAmountMinor, 'currency': 'INR'},
      'category': category,
      'priority': priority ?? 3,
      'importance': (importance ?? ItemImportance.wouldLove).wireValue,
      'quantity': quantity ?? 1,
      'giftPreferences': const {
        'color': null,
        'size': null,
        'variantNotes': null,
      },
      'status': 'available',
      'position': position,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _writeItems([...items, row]);
    return WishlistItem.fromJson(row);
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
    await _ready();
    await Future<void>.delayed(_latency);
    final items = _readItems();
    final index = items.indexWhere(
      (i) => i['id'] == itemId && i['wishlistId'] == wishlistId,
    );
    if (index == -1) throw StateError('Item $itemId not found');
    final row = items[index];
    if (recipientName != null) row['recipientName'] = recipientName;
    if (relation != null) row['relation'] = relation;
    if (occasionKey != null) row['occasionKey'] = occasionKey;
    if (notes != null) row['notes'] = notes;
    if (priority != null) row['priority'] = priority;
    if (importance != null) row['importance'] = importance.wireValue;
    await _writeItems(items);
    return WishlistItem.fromJson(row);
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
    await _ready();
    final product = DevProductRepository.catalog.firstWhere(
      (p) => p.provider == provider && p.externalId == externalId,
      orElse: () => DevProductRepository.catalog.first,
    );
    final created = await addItem(
      wishlistId,
      title: product.title,
      notes: notes,
      recipientName: recipientName,
      relation: relation,
      productLink: product.productUrl,
      priceAmountMinor: product.amountMinor,
      category: product.category,
      priority: priority,
      quantity: quantity,
      mediaIds: product.imageUrls,
    );

    // Stamped after the fact because `addItem` is the shared interface method
    // and has no parameter for it. Without this the detail screen sees a null
    // `sourceProductId` and never asks for the catalogue record, so dev mode
    // would silently exercise a different path from a real backend.
    final rows = _readItems();
    final index = rows.indexWhere((r) => r['id'] == created.id);
    if (index == -1) return created;
    rows[index]['sourceProductId'] = product.externalId;
    await _writeItems(rows);
    return WishlistItem.fromJson(Map<String, dynamic>.from(rows[index]));
  }

  @override
  Future<void> removeItem(String wishlistId, String itemId) async {
    await _ready();
    final items = _readItems()
        .where((i) => !(i['id'] == itemId && i['wishlistId'] == wishlistId))
        .toList();
    await _writeItems(items);
  }

  @override
  Future<List<WishlistItem>> reorderItems(
    String wishlistId,
    List<String> itemIds,
  ) async {
    await _ready();
    await Future<void>.delayed(_latency);
    final items = _readItems();
    for (final item in items.where((i) => i['wishlistId'] == wishlistId)) {
      final position = itemIds.indexOf(item['id'] as String);
      if (position != -1) item['position'] = position;
    }
    await _writeItems(items);
    final mine = items.where((i) => i['wishlistId'] == wishlistId).toList()
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    return mine.map(WishlistItem.fromJson).toList();
  }

  // ── Sharing ───────────────────────────────────────────────────────────────

  @override
  Future<List<Wishlist>> listSharedWithMe() async {
    await _ready();
    await Future<void>.delayed(_latency);
    final items = _readItems();
    return _readWishlists()
        .where((r) => r['sharedWithMe'] == true && r['archivedAt'] == null)
        .map((r) => _toWishlist(r, items))
        .toList();
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
    await _ready();
    await Future<void>.delayed(_latency);
    final rows = _readWishlists();
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index == -1) throw StateError('Wishlist $id not found');

    // Rotating mints a new slug, so a link copied before the rotate stops
    // resolving — the same contract the real endpoint has.
    final slug = rotate == true
        ? 'dev-${DateTime.now().microsecondsSinceEpoch}'
        : 'dev-$id';

    return ShareInfo(
      slug: slug,
      url: 'https://wishtick.dev/w/$slug',
      hasPasscode: clearPasscode ? false : passcode != null,
      expiresAt: clearExpiry ? null : expiresAt,
    );
  }

  // ── Participants ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _readParticipants() =>
      (jsonDecode(_prefs.getString(DevKeys.wishlistParticipants) ?? '[]')
              as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<void> _writeParticipants(List<Map<String, dynamic>> rows) =>
      _prefs.setString(DevKeys.wishlistParticipants, jsonEncode(rows));

  @override
  Future<List<WishlistParticipant>> listParticipants(String wishlistId) async {
    await _ready();
    await Future<void>.delayed(_latency);
    return _readParticipants()
        .where((r) => r['wishlistId'] == wishlistId)
        .map(WishlistParticipant.fromJson)
        .toList();
  }

  @override
  Future<WishlistParticipant> addParticipant(
    String wishlistId, {
    required String userId,
    ParticipantRole role = ParticipantRole.viewer,
  }) async {
    await _ready();
    await Future<void>.delayed(_latency);

    final rows = _readParticipants();
    final duplicate = rows.any(
      (r) => r['wishlistId'] == wishlistId && r['userId'] == userId,
    );
    // Same 409 the real endpoint answers with, so the screen's duplicate
    // handling is exercised in dev rather than only in production.
    if (duplicate) {
      throw StateError('This person already has access to the wishlist');
    }

    final row = <String, dynamic>{
      'id': 'p_${DateTime.now().microsecondsSinceEpoch}',
      'wishlistId': wishlistId,
      'userId': userId,
      'name': null,
      'role': role.wireValue,
      // A WishMate has an account already, so there is nothing left to claim.
      'state': 'accepted',
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _writeParticipants([...rows, row]);
    return WishlistParticipant.fromJson(row);
  }

  @override
  Future<void> revokeParticipant(
    String wishlistId,
    String participantId,
  ) async {
    await _ready();
    await Future<void>.delayed(_latency);
    final rows = _readParticipants()
      ..removeWhere(
        (r) => r['wishlistId'] == wishlistId && r['id'] == participantId,
      );
    await _writeParticipants(rows);
  }

  @override
  Future<PublicWishlist> publicBySlug(String slug, {String? passcode}) async {
    await _ready();
    await Future<void>.delayed(_latency);

    // Dev slugs are `dev-<wishlistId>`; anything else has no local wishlist.
    final id = slug.startsWith('dev-') ? slug.substring(4) : slug;
    final row = _readWishlists().firstWhere(
      (r) => r['id'] == id,
      orElse: () => throw StateError('Share link not found'),
    );
    final items = _readItems().where((i) => i['wishlistId'] == id).toList()
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));

    return PublicWishlist(
      title: row['title'] as String,
      description: row['description'] as String?,
      coverUrl: row['coverUrl'] as String?,
      // First name only, matching the real view's redaction.
      ownerFirstName: 'Ananya',
      itemCount: items.length,
      items: items.map((i) {
        final status = i['status'] as String? ?? 'available';
        return PublicWishlistItem(
          id: i['id'] as String,
          title: i['title'] as String,
          notes: i['notes'] as String?,
          imageUrls: (i['imageUrls'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
          productLink: i['productLink'] as String?,
          price: ItemPrice.fromJson(
            i['price'] as Map<String, dynamic>? ?? const {},
          ),
          category: i['category'] as String?,
          priority: i['priority'] as int? ?? 3,
          importance: ItemImportance.fromWire(i['importance'] as String?),
          quantity: i['quantity'] as int? ?? 1,
          giftPreferences: GiftPreferences.fromJson(
            i['giftPreferences'] as Map<String, dynamic>? ?? const {},
          ),
          isClaimed: status != 'available',
        );
      }).toList(),
    );
  }

  // ── Seed data ─────────────────────────────────────────────────────────────
  // Ananya's Wishlist's items match UI_Screen/280-212.png by name exactly;
  // the other two wishlists have no reference mock, so their items are
  // plausible fixtures rather than pixel-matched content.

  static final List<Map<String, dynamic>> _seedWishlists = [
    {
      'id': 'dev-wl-1',
      'title': "Ananya's Wishlist",
      'description': 'A few special things for Ananya',
      'occasionLabel': null,
      'visibility': 'public',
      'coverUrl': null,
      'chatEnabled': true,
      'eventId': null,
      'archivedAt': null,
      'createdAt': '2026-06-01T10:00:00.000Z',
      'updatedAt': '2026-06-01T10:00:00.000Z',
    },
    {
      'id': 'dev-wl-2',
      'title': 'Anniversary Picks',
      'description': null,
      'occasionLabel': 'Anniversary',
      'visibility': 'public',
      'coverUrl': null,
      'chatEnabled': true,
      'eventId': null,
      'archivedAt': null,
      'createdAt': '2026-06-02T10:00:00.000Z',
      'updatedAt': '2026-06-02T10:00:00.000Z',
    },
    {
      'id': 'dev-wl-3',
      'title': 'Travel Bucket List',
      'description': null,
      'occasionLabel': null,
      'visibility': 'private',
      'coverUrl': null,
      'chatEnabled': true,
      'eventId': null,
      'archivedAt': null,
      'createdAt': '2026-06-03T10:00:00.000Z',
      'updatedAt': '2026-06-03T10:00:00.000Z',
    },
    {
      'id': _friendWishlistId,
      'title': "Siya's Wishlist",
      'description': null,
      'occasionLabel': 'Birthday',
      'visibility': 'public',
      'coverUrl': null,
      'chatEnabled': true,
      'eventId': null,
      'archivedAt': null,
      'createdAt': '2026-07-14T10:00:00.000Z',
      'updatedAt': '2026-07-14T10:00:00.000Z',
      // The one list you do not own — without it nothing in the gifting flow
      // is reachable, because you can never gift your own item.
      'sharedWithMe': true,
    },
  ];

  static Map<String, dynamic> _item({
    required String id,
    required String wishlistId,
    required String title,
    required int priceAmountMinor,
    required int position,
  }) => {
    'id': id,
    'wishlistId': wishlistId,
    'title': title,
    'notes': null,
    'recipientName': null,
    'relation': null,
    'occasionKey': null,
    'imageUrls': const <String>[],
    'productLink': null,
    'price': {'amountMinor': priceAmountMinor, 'currency': 'INR'},
    'category': null,
    'priority': 3,
    'importance': 'would_love',
    'quantity': 1,
    'giftPreferences': const {
      'color': null,
      'size': null,
      'variantNotes': null,
    },
    'status': 'available',
    'position': position,
    'createdAt': '2026-06-01T10:00:00.000Z',
  };

  static final List<Map<String, dynamic>> _seedItems = [
    _item(
      id: 'dev-item-1',
      wishlistId: 'dev-wl-1',
      title: 'Nike Air Max Sneakers',
      priceAmountMinor: 1099900,
      position: 0,
    ),
    _item(
      id: 'dev-item-2',
      wishlistId: 'dev-wl-1',
      title: 'Michael Kors Handbag',
      priceAmountMinor: 1699900,
      position: 1,
    ),
    _item(
      id: 'dev-item-3',
      wishlistId: 'dev-wl-1',
      title: 'Dyson Airwrap Hairstyling Tool',
      priceAmountMinor: 3899900,
      position: 2,
    ),
    _item(
      id: 'dev-item-4',
      wishlistId: 'dev-wl-1',
      title: 'Sony WH-1000XM5 Headphones',
      priceAmountMinor: 2999000,
      position: 3,
    ),
    _item(
      id: 'dev-item-5',
      wishlistId: 'dev-wl-1',
      title: 'Boat Rockerz 450 Headphones',
      priceAmountMinor: 149900,
      position: 4,
    ),
    _item(
      id: 'dev-item-6',
      wishlistId: 'dev-wl-1',
      title: 'Apple AirPods Pro (2nd Gen)',
      priceAmountMinor: 2490000,
      position: 5,
    ),

    _item(
      id: 'dev-item-7',
      wishlistId: 'dev-wl-2',
      title: 'Fossil Gen 6 Smartwatch',
      priceAmountMinor: 2299000,
      position: 0,
    ),
    _item(
      id: 'dev-item-8',
      wishlistId: 'dev-wl-2',
      title: 'Le Creuset Dutch Oven',
      priceAmountMinor: 3499000,
      position: 1,
    ),
    _item(
      id: 'dev-item-9',
      wishlistId: 'dev-wl-2',
      title: 'Kindle Paperwhite',
      priceAmountMinor: 1399900,
      position: 2,
    ),
    _item(
      id: 'dev-item-10',
      wishlistId: 'dev-wl-2',
      title: 'Bose SoundLink Speaker',
      priceAmountMinor: 1999900,
      position: 3,
    ),
    _item(
      id: 'dev-item-11',
      wishlistId: 'dev-wl-2',
      title: 'Egyptian Cotton Bedsheet Set',
      priceAmountMinor: 499900,
      position: 4,
    ),
    _item(
      id: 'dev-item-12',
      wishlistId: 'dev-wl-2',
      title: 'Nespresso Vertuo Machine',
      priceAmountMinor: 1499900,
      position: 5,
    ),
    _item(
      id: 'dev-item-13',
      wishlistId: 'dev-wl-2',
      title: 'Personalised Photo Album',
      priceAmountMinor: 99900,
      position: 6,
    ),
    _item(
      id: 'dev-item-14',
      wishlistId: 'dev-wl-2',
      title: 'Scented Candle Set',
      priceAmountMinor: 149900,
      position: 7,
    ),

    _item(
      id: 'dev-item-15',
      wishlistId: 'dev-wl-3',
      title: 'Anti-theft Travel Backpack',
      priceAmountMinor: 349900,
      position: 0,
    ),
    _item(
      id: 'dev-item-16',
      wishlistId: 'dev-wl-3',
      title: 'Universal Travel Adapter',
      priceAmountMinor: 99900,
      position: 1,
    ),
    _item(
      id: 'dev-item-17',
      wishlistId: 'dev-wl-3',
      title: 'Noise Cancelling Earbuds',
      priceAmountMinor: 799900,
      position: 2,
    ),
    _item(
      id: 'dev-item-18',
      wishlistId: 'dev-wl-3',
      title: 'Hardshell Cabin Suitcase',
      priceAmountMinor: 649900,
      position: 3,
    ),
    _item(
      id: 'dev-item-19',
      wishlistId: 'dev-wl-3',
      title: 'Instant Camera',
      priceAmountMinor: 549900,
      position: 4,
    ),
    _item(
      id: 'dev-item-20',
      wishlistId: 'dev-wl-3',
      title: 'Packing Cube Set',
      priceAmountMinor: 129900,
      position: 5,
    ),

    // Siya's list — the gifting flow's entry point. Every item carries the
    // recipient/occasion the Gift summary card (Figma `291:1170`) renders, and
    // a real merchant link so "Gift Now" has somewhere to go.
    _friendItem(
      id: 'dev-item-21',
      title: 'Nike Air Max Sneakers',
      priceAmountMinor: 1099900,
      position: 0,
      productLink: 'https://www.amazon.in/dp/B0BPHDF1YR',
    ),
    _friendItem(
      id: 'dev-item-22',
      title: 'Michael Kors Women Handbag',
      priceAmountMinor: 1699900,
      position: 1,
      productLink: 'https://www.myntra.com/handbags/michael-kors',
      notes:
          'She has wanted this for years! This will make her styling more '
          'beautiful.',
      importance: 'must_have',
      priority: 1,
    ),
    _friendItem(
      id: 'dev-item-23',
      title: 'Dyson Air wrap Hairstyling Tool',
      priceAmountMinor: 3899900,
      position: 2,
      productLink: 'https://www.flipkart.com/dyson-airwrap',
    ),
    _friendItem(
      id: 'dev-item-24',
      title: 'Sony WH-1000XMS Headphones',
      priceAmountMinor: 2999000,
      position: 3,
      productLink: 'https://www.amazon.in/dp/B0BXYCS74H',
    ),
    _friendItem(
      id: 'dev-item-25',
      title: 'Boat Rockerz 450 Bluetooth',
      priceAmountMinor: 149900,
      position: 4,
      productLink: 'https://www.amazon.in/dp/B07PR1CL3S',
    ),
    _friendItem(
      id: 'dev-item-26',
      title: 'Apple Airpods Pro (2 Gen)',
      priceAmountMinor: 2490000,
      position: 5,
      productLink: 'https://www.amazon.in/dp/B0CHWRXH8B',
    ),
  ];

  /// An item on Siya's list. Split from [_item] because these carry the fields
  /// a friend's product page shows and an owner's does not need.
  static Map<String, dynamic> _friendItem({
    required String id,
    required String title,
    required int priceAmountMinor,
    required int position,
    required String productLink,
    String? notes,
    String importance = 'would_love',
    int priority = 3,
  }) => {
    ..._item(
      id: id,
      wishlistId: _friendWishlistId,
      title: title,
      priceAmountMinor: priceAmountMinor,
      position: position,
    ),
    'notes': notes,
    'recipientName': 'Siya',
    'relation': 'Friend',
    'occasionKey': 'birthday',
    'productLink': productLink,
    'importance': importance,
    'priority': priority,
    'createdAt': '2026-07-14T10:00:00.000Z',
  };
}

/// A small fixed catalogue standing in for real search/scrape results.
class DevProductRepository implements ProductRepository {
  static const _latency = Duration(milliseconds: 300);

  static final List<NormalizedProduct> catalog = [
    const NormalizedProduct(
      provider: 'fixture',
      externalId: 'p1',
      title: 'Apple AirPods Pro (2nd Gen)',
      description: 'Active noise cancellation, adaptive audio.',
      imageUrls: [],
      productUrl: 'https://www.apple.com/in/airpods-pro/',
      affiliateUrl: null,
      amountMinor: 2490000,
      listPriceMinor: 3299000,
      currency: 'INR',
      merchant: 'Apple Store',
      category: 'electronics',
      inStock: true,
    ),
    const NormalizedProduct(
      provider: 'fixture',
      externalId: 'p2',
      title: 'Nike Air Max Sneakers',
      description: 'Everyday comfort with visible Air cushioning.',
      imageUrls: [],
      productUrl: 'https://www.nike.com/in/',
      affiliateUrl: null,
      amountMinor: 1099900,
      listPriceMinor: null,
      currency: 'INR',
      merchant: 'Nike',
      category: 'fashion',
      inStock: true,
    ),
    const NormalizedProduct(
      provider: 'fixture',
      externalId: 'p3',
      title: 'Sony WH-1000XM5 Headphones',
      description: 'Industry-leading noise cancellation.',
      imageUrls: [],
      productUrl: 'https://www.sony.co.in/',
      affiliateUrl: null,
      amountMinor: 2999000,
      listPriceMinor: 3499000,
      currency: 'INR',
      merchant: 'Sony',
      category: 'electronics',
      inStock: true,
    ),
    const NormalizedProduct(
      provider: 'fixture',
      externalId: 'p4',
      title: 'Fossil Gen 6 Smartwatch',
      description: 'Track workouts, sleep, and notifications.',
      imageUrls: [],
      productUrl: 'https://www.fossil.com/en-in/',
      affiliateUrl: null,
      amountMinor: 2299000,
      listPriceMinor: null,
      currency: 'INR',
      merchant: 'Fossil',
      category: 'fashion',
      inStock: true,
    ),
    const NormalizedProduct(
      provider: 'fixture',
      externalId: 'p5',
      title: 'Kindle Paperwhite',
      description: 'Glare-free display, weeks of battery life.',
      imageUrls: [],
      productUrl: 'https://www.amazon.in/',
      affiliateUrl: null,
      amountMinor: 1399900,
      listPriceMinor: 1799900,
      currency: 'INR',
      merchant: 'Amazon',
      category: 'electronics',
      inStock: true,
    ),
    const NormalizedProduct(
      provider: 'fixture',
      externalId: 'p6',
      title: 'Bose SoundLink Speaker',
      description: 'Portable Bluetooth speaker.',
      imageUrls: [],
      productUrl: 'https://www.bose.in/',
      affiliateUrl: null,
      amountMinor: 1999900,
      listPriceMinor: null,
      currency: 'INR',
      merchant: 'Bose',
      category: 'electronics',
      inStock: true,
    ),
    const NormalizedProduct(
      provider: 'fixture',
      externalId: 'p7',
      title: 'Instant Camera',
      description: 'Print photos on the spot.',
      imageUrls: [],
      productUrl: 'https://www.fujifilm.com/in/',
      affiliateUrl: null,
      amountMinor: 549900,
      listPriceMinor: 699900,
      currency: 'INR',
      merchant: 'Fujifilm',
      category: 'electronics',
      inStock: true,
    ),
    const NormalizedProduct(
      provider: 'fixture',
      externalId: 'p8',
      title: 'Le Creuset Dutch Oven',
      description: 'Enamelled cast iron, even heat retention.',
      imageUrls: [],
      productUrl: 'https://www.lecreuset.in/',
      affiliateUrl: null,
      amountMinor: 3499000,
      listPriceMinor: null,
      currency: 'INR',
      merchant: 'Le Creuset',
      category: 'home',
      inStock: true,
    ),
  ];

  @override
  Future<NormalizedProduct> details({
    required String provider,
    required String externalId,
  }) async {
    await Future<void>.delayed(_latency);
    // Dev mode has no second upstream call to make, so the catalogue row is
    // already the whole record — the screen simply re-renders what it has.
    return catalog.firstWhere(
      (p) => p.externalId == externalId,
      orElse: () => catalog.first,
    );
  }

  @override
  Future<NormalizedProduct> detailsById(String productId) async {
    await Future<void>.delayed(_latency);
    // The dev catalogue has no server-side ids, so a saved item's
    // `sourceProductId` is its externalId here — see DevWishlistRepository,
    // which writes it that way when importing.
    return catalog.firstWhere(
      (p) => p.externalId == productId,
      orElse: () => catalog.first,
    );
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
    await Future<void>.delayed(_latency);
    final q = query?.trim().toLowerCase();
    final matches = catalog.where((p) {
      final matchesQuery =
          q == null || q.isEmpty || p.title.toLowerCase().contains(q);
      final matchesCategory = category == null || p.category == category;
      final matchesMin =
          minPriceMinor == null || (p.amountMinor ?? 0) >= minPriceMinor;
      final matchesMax =
          maxPriceMinor == null || (p.amountMinor ?? 0) <= maxPriceMinor;
      return matchesQuery && matchesCategory && matchesMin && matchesMax;
    }).toList();
    return ProductSearchResult(
      items: matches,
      page: page,
      pageSize: pageSize,
      totalEstimate: matches.length,
      hasMore: false,
      freshness: ResultFreshness.live,
    );
  }

  @override
  Future<ResolvedUrlProduct> resolveUrl(String url) async {
    await Future<void>.delayed(_latency);
    final known = catalog.firstWhere(
      (p) => url.contains(Uri.parse(p.productUrl).host),
      orElse: () => catalog.first,
    );
    return ResolvedUrlProduct(
      fromKnownProvider: true,
      title: known.title,
      productUrl: url,
      description: known.description,
      imageUrls: known.imageUrls,
      amountMinor: known.amountMinor,
      currency: known.currency,
      provider: known.provider,
      externalId: known.externalId,
    );
  }
}

/// Skips the real upload-url/PUT/confirm handshake entirely: the picked
/// file's own local path stands in as both id and url, which
/// [WishtickImage] already knows how to render via `Image.file`.
class DevMediaRepository implements MediaRepository {
  static const _latency = Duration(milliseconds: 300);

  @override
  Future<MediaView> uploadFile({
    required XFile file,
    required MediaPurpose purpose,
    String? fileName,
  }) async {
    await Future<void>.delayed(_latency);
    return MediaView(
      id: file.path,
      url: file.path,
      purpose: purpose.wireValue,
      contentType: file.mimeType,
      sizeBytes: await file.length(),
    );
  }
}
