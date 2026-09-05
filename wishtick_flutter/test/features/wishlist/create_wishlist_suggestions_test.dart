import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/create_wishlist_screen.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';

import '../../helpers/onboarding_fakes.dart';
import '../../helpers/wishlist_fakes.dart';
import '../../helpers/wishmates_fakes.dart';

/// Suggestions on Create Wishlist: WishMates under the name, occasions under
/// the occasion.
///
/// Picking a WishMate does more than fill the field — it links the list to
/// them, so the tests care as much about what is *sent* as what is shown.
void main() {
  late FakeWishlistRepository wishlists;

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 1800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    wishlists = FakeWishlistRepository();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          wishlistRepositoryProvider.overrideWithValue(wishlists),
          wishmatesRepositoryProvider.overrideWithValue(
            FakeWishmatesRepository(
              mates: [
                buildWishmate(userId: 'u_1', displayName: 'Siya Kapoor'),
                buildWishmate(userId: 'u_2', displayName: 'Priyal Sharma'),
              ],
            ),
          ),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CreateWishlistScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // By position, not label: the required label is drawn as rich text with an
  // asterisk, so no plain Text reads exactly 'Wishlist Name'. The name field
  // is the first field on the screen.
  Finder nameField() => find.byType(TextFormField).first;
  Finder occasionField() => find.byType(TextFormField).at(1);

  testWidgets('typing a name offers the WishMates it could be', (tester) async {
    await pump(tester);

    // Nothing under an empty field: a wall of every friend is a directory.
    expect(find.text('Siya Kapoor'), findsNothing);

    await tester.enterText(nameField(), 'si');
    await tester.pumpAndSettle();

    expect(find.text('Siya Kapoor'), findsOneWidget);
    expect(find.text('Priyal Sharma'), findsNothing);
  });

  testWidgets('picking one puts their name in the field, with no chip', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(nameField(), 'si');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siya Kapoor'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(nameField()).controller!.text,
      'Siya Kapoor',
    );
    // No chip beside the field: one read as though a second WishMate could be
    // added next.
    expect(find.byType(InputChip), findsNothing);
    expect(find.textContaining('For Siya'), findsNothing);
    // And the rows step aside once one is chosen.
    expect(find.widgetWithText(ListTile, 'Siya Kapoor'), findsNothing);
  });

  // The link is invisible now, so this is what tells it apart: a typed name is
  // *not* a link, and the rows stay up offering to make one.
  //
  // A prefix, not the whole name: matching is per word, so "Siya Kapoor"
  // matches no single word and would offer nothing for the wrong reason.
  testWidgets('a typed name is not a link, and still offers one', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(nameField(), 'siya');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Siya Kapoor'), findsOneWidget);
  });

  // "Camping gear" quietly still linked to Siya is the stale link nobody
  // notices until it is wrong. With the chip gone the rows coming back are how
  // you can see the link was dropped.
  testWidgets('editing the name away from theirs drops the link', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(nameField(), 'si');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siya Kapoor'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Siya Kapoor'), findsNothing);

    await tester.enterText(nameField(), 'siya');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Siya Kapoor'), findsOneWidget);
  });

  testWidgets('a name that matches nobody is still a fine name', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(nameField(), 'Camping gear');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Siya Kapoor'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Priyal Sharma'), findsNothing);
  });

  // Images with labels, as Home draws them, right under the field.
  testWidgets('offers the occasions as a grid of pictures', (tester) async {
    await pump(tester);

    expect(find.text('Birthday'), findsOneWidget);
    expect(find.text('Anniversary'), findsOneWidget);
    // An action on Home, not an occasion a wishlist could be for.
    expect(find.text('Custom Events'), findsNothing);
  });

  testWidgets('tapping an occasion fills the field', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Anniversary'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(occasionField()).controller!.text,
      'Anniversary',
    );
  });

  testWidgets('typing narrows the grid, and free text is still allowed', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(occasionField(), 'wed');
    await tester.pumpAndSettle();
    expect(find.text('Wedding'), findsOneWidget);
    expect(find.text('Birthday'), findsNothing);

    // A reason to give a gift that the taxonomy has never heard of.
    await tester.enterText(occasionField(), 'Passed the bar');
    await tester.pumpAndSettle();
    expect(find.text('Wedding'), findsNothing);
    expect(
      tester.widget<TextFormField>(occasionField()).controller!.text,
      'Passed the bar',
    );
  });

  testWidgets('occasion is required now', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Save Wishlist'));
    await tester.pumpAndSettle();

    expect(find.text('Please choose an occasion'), findsOneWidget);
  });

  // Showing the message is not the same as refusing to save. Edit mode fills
  // every other field from the list being edited, so occasion is the only
  // thing missing — nothing else can mask a guard that is not there.
  testWidgets('a missing occasion actually blocks the save', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 1800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeWishlistRepository();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          wishlistRepositoryProvider.overrideWithValue(repo),
          wishmatesRepositoryProvider.overrideWithValue(
            FakeWishmatesRepository(mates: const []),
          ),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: CreateWishlistScreen(
            // buildWishlist leaves occasionLabel null; the cover fills _cover.
            editing: buildWishlist(id: 'wl_1', coverUrl: 'https://x/cover.jpg'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 'Save Changes' in edit mode, not 'Save Wishlist'.
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Please choose an occasion'), findsOneWidget);
    expect(repo.updateCalls, isEmpty);
  });

  testWidgets('the field is who the list is for', (tester) async {
    await pump(tester);
    // textContaining, not text: the required label is rich text with an
    // asterisk, and find.text only sees plain Text widgets.
    expect(find.textContaining('WishMate'), findsOneWidget);
    expect(find.textContaining('Wishlist Name'), findsNothing);
  });
}
