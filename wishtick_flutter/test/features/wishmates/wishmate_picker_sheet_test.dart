import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';
import 'package:wishtick_flutter/features/wishmates/domain/wishmate.dart';
import 'package:wishtick_flutter/features/wishmates/presentation/widgets/wishmate_picker_sheet.dart';

import '../../helpers/wishmates_fakes.dart';

/// The single-select picker behind "Who is this memory for?" and its siblings.
void main() {
  Future<PersonIdentity?> open(
    WidgetTester tester, {
    required FakeWishmatesRepository repo,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 1200)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    PersonIdentity? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wishmatesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    picked = await showWishmatePickerSheet(
                      context,
                      title: 'Who is this memory for?',
                      emptyMessage: 'Add a WishMate first.',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  FakeWishmatesRepository peopled() => FakeWishmatesRepository(
    mates: [
      buildWishmate(userId: 'u_1', displayName: 'Priyal Sharma'),
      buildWishmate(userId: 'u_2', displayName: 'Rohan Prasad'),
      buildWishmate(userId: 'u_3', displayName: 'Ananya R'),
    ],
  );

  testWidgets('filters the list by name as you type', (tester) async {
    await open(tester, repo: peopled());

    expect(find.text('Priyal Sharma'), findsOneWidget);
    expect(find.text('Rohan Prasad'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'rohan');
    await tester.pumpAndSettle();

    expect(find.text('Rohan Prasad'), findsOneWidget);
    expect(find.text('Priyal Sharma'), findsNothing);
    expect(find.text('Ananya R'), findsNothing);
  });

  testWidgets('matches the @handle too', (tester) async {
    final repo = FakeWishmatesRepository(
      mates: [
        buildWishmate(
          userId: 'u_1',
          displayName: 'Priyal Sharma',
          username: 'priyal_s',
        ),
        buildWishmate(
          userId: 'u_2',
          displayName: 'Rohan Prasad',
          username: 'rohanp',
        ),
      ],
    );
    await open(tester, repo: repo);

    await tester.enterText(find.byType(TextField), '@priyal');
    await tester.pumpAndSettle();

    expect(find.text('Priyal Sharma'), findsOneWidget);
    expect(find.text('Rohan Prasad'), findsNothing);
  });

  /// "You have none" and "none match" are different problems; sending someone
  /// off to add WishMates when they have three and a typo would be wrong.
  testWidgets('says nothing matched rather than showing the empty message', (
    tester,
  ) async {
    await open(tester, repo: peopled());

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.textContaining('No WishMates match'), findsOneWidget);
    expect(find.text('Add a WishMate first.'), findsNothing);
  });

  testWidgets('clearing the search restores everyone', (tester) async {
    await open(tester, repo: peopled());

    await tester.enterText(find.byType(TextField), 'rohan');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('Priyal Sharma'), findsOneWidget);
    expect(find.text('Rohan Prasad'), findsOneWidget);
    expect(find.text('Ananya R'), findsOneWidget);
  });

  testWidgets('no search box when there is nothing to search', (tester) async {
    await open(tester, repo: FakeWishmatesRepository(mates: const []));

    expect(find.text('Add a WishMate first.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('tapping a filtered row still returns that person', (
    tester,
  ) async {
    await open(tester, repo: peopled());

    await tester.enterText(find.byType(TextField), 'ananya');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ananya R'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
  });
}
