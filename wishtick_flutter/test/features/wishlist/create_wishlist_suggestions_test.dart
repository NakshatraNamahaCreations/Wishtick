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

  testWidgets('typing a name offers the WishMates it could be', (tester) async {
    await pump(tester);

    // Nothing under an empty field: a wall of every friend is a directory.
    expect(find.text('Siya Kapoor'), findsNothing);

    await tester.enterText(nameField(), 'si');
    await tester.pumpAndSettle();

    expect(find.text('Siya Kapoor'), findsOneWidget);
    expect(find.text('Priyal Sharma'), findsNothing);
  });

  testWidgets('picking one names the list after them and links it', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(nameField(), 'si');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siya Kapoor'));
    await tester.pumpAndSettle();

    // Filled, and the link is said out loud with a way to undo it.
    expect(
      tester.widget<TextFormField>(nameField()).controller!.text,
      'Siya Kapoor',
    );
    expect(find.text('For Siya Kapoor'), findsOneWidget);
    // The name strip gives way to the pill. Not "no ActionChip at all": the
    // occasion suggestions beneath are chips too, and stay.
    expect(find.widgetWithText(ActionChip, 'Siya Kapoor'), findsNothing);
  });

  // "Camping gear" quietly still linked to Siya is the stale link nobody
  // notices until it is wrong.
  testWidgets('editing the name away from theirs drops the link', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(nameField(), 'si');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siya Kapoor'));
    await tester.pumpAndSettle();

    await tester.enterText(nameField(), 'Camping gear');
    await tester.pumpAndSettle();

    expect(find.text('For Siya Kapoor'), findsNothing);
  });

  testWidgets('the cross on the pill unlinks without clearing the name', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(nameField(), 'si');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siya Kapoor'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Unlink'));
    await tester.pumpAndSettle();

    expect(find.text('For Siya Kapoor'), findsNothing);
    expect(
      tester.widget<TextFormField>(nameField()).controller!.text,
      'Siya Kapoor',
    );
  });

  testWidgets('a name that matches nobody is still a fine name', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(nameField(), 'Camping gear');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, 'Siya Kapoor'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Priyal Sharma'), findsNothing);
    expect(find.textContaining('For '), findsNothing);
  });

  testWidgets('occasion suggestions fill the field', (tester) async {
    await pump(tester);

    // The taxonomy the fake onboarding repository serves.
    expect(find.text('Birthday'), findsOneWidget);
    await tester.tap(find.text('Birthday'));
    await tester.pumpAndSettle();

    final occasion = find.widgetWithText(TextFormField, 'Occasion (Optional)');
    expect(tester.widget<TextFormField>(occasion).controller!.text, 'Birthday');
  });
}
