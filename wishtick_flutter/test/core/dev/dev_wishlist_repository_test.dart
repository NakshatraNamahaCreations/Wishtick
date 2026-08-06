import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wishtick_flutter/core/dev/dev_repositories.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> emptyPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  group('seeding', () {
    test('seeds three wishlists on first use, once', () async {
      final prefs = await emptyPrefs();
      final repo = DevWishlistRepository(prefs);

      final wishlists = await repo.listMine();

      expect(wishlists, hasLength(3));
      expect(wishlists.map((w) => w.title), [
        "Ananya's Wishlist",
        'Anniversary Picks',
        'Travel Bucket List',
      ]);
    });

    test('does not reseed on a later instance (survives restart)', () async {
      final prefs = await emptyPrefs();
      await DevWishlistRepository(prefs).listMine();
      // Simulates a fresh app launch reading the same persisted prefs.
      final restarted = DevWishlistRepository(prefs);

      await restarted.archive('dev-wl-1');
      final wishlists = await restarted.listMine();

      // Still three seed rows, not six — archive mutated one rather than
      // the seed running twice.
      expect(wishlists, hasLength(2));
    });
  });

  group('items', () {
    test("Ananya's Wishlist seeds with 6 items matching the design", () async {
      final prefs = await emptyPrefs();
      final repo = DevWishlistRepository(prefs);
      await repo.listMine();

      final items = await repo.listItems('dev-wl-1');

      expect(items, hasLength(6));
      expect(items.map((i) => i.title), contains('Nike Air Max Sneakers'));
    });

    test('addItem appends at the next position', () async {
      final prefs = await emptyPrefs();
      final repo = DevWishlistRepository(prefs);
      await repo.listMine();
      final before = await repo.listItems('dev-wl-3');

      final created = await repo.addItem('dev-wl-3', title: 'New gift');

      expect(created.position, before.length);
      final after = await repo.listItems('dev-wl-3');
      expect(after, hasLength(before.length + 1));
    });

    test('removeItem drops the row and getItem stops finding it', () async {
      final prefs = await emptyPrefs();
      final repo = DevWishlistRepository(prefs);
      await repo.listMine();
      final items = await repo.listItems('dev-wl-1');
      final target = items.first;

      await repo.removeItem('dev-wl-1', target.id);

      final remaining = await repo.listItems('dev-wl-1');
      expect(remaining.map((i) => i.id), isNot(contains(target.id)));
      expect(
        () => repo.getItem('dev-wl-1', target.id),
        throwsA(isA<StateError>()),
      );
    });

    test('updateItem applies recipient/relation/occasion/importance', () async {
      final prefs = await emptyPrefs();
      final repo = DevWishlistRepository(prefs);
      await repo.listMine();
      final target = (await repo.listItems('dev-wl-1')).first;

      final updated = await repo.updateItem(
        'dev-wl-1',
        target.id,
        recipientName: 'Ananya',
        relation: 'Best Friend',
        occasionKey: 'birthday',
        importance: ItemImportance.mustHave,
      );

      expect(updated.recipientName, 'Ananya');
      expect(updated.relation, 'Best Friend');
      expect(updated.occasionKey, 'birthday');
      expect(updated.importance, ItemImportance.mustHave);
    });

    test('addItemFromProduct snapshots a catalogue fixture', () async {
      final prefs = await emptyPrefs();
      final repo = DevWishlistRepository(prefs);
      await repo.listMine();

      final created = await repo.addItemFromProduct(
        'dev-wl-2',
        provider: 'fixture',
        externalId: 'p2',
      );

      expect(created.title, 'Nike Air Max Sneakers');
      expect(created.productLink, isNotNull);
    });
  });

  group('wishlists', () {
    test('create adds a wishlist visible in listMine', () async {
      final prefs = await emptyPrefs();
      final repo = DevWishlistRepository(prefs);
      await repo.listMine();

      final created = await repo.create(
        title: 'Housewarming',
        visibility: WishlistVisibility.private,
      );

      final all = await repo.listMine();
      expect(all.map((w) => w.id), contains(created.id));
    });

    test('archive hides a wishlist from listMine by default', () async {
      final prefs = await emptyPrefs();
      final repo = DevWishlistRepository(prefs);
      await repo.listMine();

      await repo.archive('dev-wl-1');

      expect(await repo.listMine(), hasLength(2));
      expect(await repo.listMine(includeArchived: true), hasLength(3));
    });

    test('update changes the visible fields', () async {
      final prefs = await emptyPrefs();
      final repo = DevWishlistRepository(prefs);
      await repo.listMine();

      final updated = await repo.update(
        'dev-wl-1',
        title: 'Renamed',
        visibility: WishlistVisibility.private,
      );

      expect(updated.title, 'Renamed');
      expect(updated.visibility, WishlistVisibility.private);
    });
  });
}
