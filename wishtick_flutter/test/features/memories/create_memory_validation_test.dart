import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/memories/data/memories_repository.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_controller.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_screen.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';

import '../../helpers/memory_fakes.dart';
import '../../helpers/wishmates_fakes.dart';

/// What happens when Save & Continue is pressed too early.
///
/// The complaint this answers: the button greys out, the missing field is
/// somewhere off screen, and pressing the button tells you nothing at all. A
/// disabled button that swallows the press is worse than no button, because it
/// looks like the app is broken rather than like the form is incomplete.
void main() {
  late FakeMemoriesRepository repo;
  late FakeWishmatesRepository mates;

  setUp(() {
    repo = FakeMemoriesRepository();
    mates = FakeWishmatesRepository(
      mates: [buildWishmate(userId: 'u_1', displayName: 'Priyal Sharma')],
    );
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        memoriesRepositoryProvider.overrideWithValue(repo),
        wishmatesRepositoryProvider.overrideWithValue(mates),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CreateMemoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapSaveAndContinue(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save & Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty form is silent until Save & Continue is pressed', (
    tester,
  ) async {
    await pump(tester);

    // Nothing is red on arrival. Marking every field before the user has
    // touched one tells them they have done something wrong by showing up.
    expect(find.text('Required'), findsNothing);
  });

  testWidgets('pressing it while incomplete names every missing field', (
    tester,
  ) async {
    final container = await pump(tester);
    container.read(createMemoryProvider.notifier).setTitle('Testing');

    await tapSaveAndContinue(tester);

    // The exact complaint: the button was grey and said nothing. It now names
    // what is missing rather than "some fields are required", which would be
    // equally useless.
    expect(
      find.text('Add the WishMate, Relation and Description to continue.'),
      findsOneWidget,
    );
  });

  testWidgets('the missing fields are outlined, and the filled ones are not', (
    tester,
  ) async {
    final container = await pump(tester);
    container.read(createMemoryProvider.notifier)
      ..setTitle('Testing')
      ..setDescription('Testing Memory');

    await tapSaveAndContinue(tester);

    // Two left: WishMate and Relation.
    expect(find.text('Required'), findsNWidgets(2));
    expect(
      find.text('Add the WishMate and Relation to continue.'),
      findsOneWidget,
    );
  });

  testWidgets('an outline clears as soon as that field is filled', (
    tester,
  ) async {
    final container = await pump(tester);
    final notifier = container.read(createMemoryProvider.notifier);
    notifier.setTitle('Testing');

    await tapSaveAndContinue(tester);
    expect(find.text('Required'), findsNWidgets(3));

    notifier.setRelation('partner_wife', 'Wife');
    await tester.pumpAndSettle();

    // Down to two. The errors track the form rather than freezing at the
    // moment they were revealed.
    expect(find.text('Required'), findsNWidgets(2));
  });

  testWidgets('a complete form moves on instead of complaining', (
    tester,
  ) async {
    final container = await pump(tester);
    container.read(createMemoryProvider.notifier)
      ..setTitle('Testing')
      ..setRecipient(buildIdentity(userId: 'u_1', displayName: 'Priyal'))
      ..setRelation('partner_wife', 'Wife')
      ..setDescription('Testing Memory');
    await tester.pumpAndSettle();

    await tapSaveAndContinue(tester);

    // A complete form navigates, and this harness has no router — so the only
    // exception allowed here is that one. Anything else would mean the press
    // took the complain-and-highlight path instead of moving on.
    expect(
      tester.takeException().toString(),
      contains('No GoRouter found in context'),
    );
    expect(find.textContaining('to continue.'), findsNothing);
    expect(find.text('Required'), findsNothing);
  });

  group('the message reads as a sentence', () {
    CreateMemoryState stateWith(List<MemoryField> present) {
      var state = const CreateMemoryState();
      if (present.contains(MemoryField.title)) {
        state = state.copyWith(title: 'T');
      }
      if (present.contains(MemoryField.recipient)) {
        state = state.copyWith(
          recipient: buildIdentity(userId: 'u_1', displayName: 'P'),
        );
      }
      if (present.contains(MemoryField.relation)) {
        state = state.copyWith(relationKey: 'r', relationLabel: 'Wife');
      }
      if (present.contains(MemoryField.description)) {
        state = state.copyWith(description: 'D');
      }
      return state;
    }

    test('one missing field needs no list', () {
      final state = stateWith([
        MemoryField.title,
        MemoryField.recipient,
        MemoryField.description,
      ]);
      expect(state.missingMessage, 'Add the Relation to continue.');
    });

    test('two are joined with "and", not a comma', () {
      final state = stateWith([MemoryField.title, MemoryField.recipient]);
      expect(
        state.missingMessage,
        'Add the Relation and Description to continue.',
      );
    });

    test('the fields are listed in the order they appear on the form', () {
      // Not in the order they happen to be checked: a list that jumps around
      // the screen is harder to act on than one that reads top to bottom.
      expect(const CreateMemoryState().missingStep1, MemoryField.values);
    });
  });
}
