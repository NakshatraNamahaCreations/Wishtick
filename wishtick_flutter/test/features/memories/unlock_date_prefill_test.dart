import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/memories/data/memories_repository.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_controller.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_unlock_screen.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';

import '../../helpers/memory_fakes.dart';
import '../../helpers/wishmates_fakes.dart';

/// Step 1 already asks which day the memory is about, so step 2 starts there
/// rather than asking the same question twice.
void main() {
  group('suggestedUnlockDate', () {
    test('uses this year when the occasion is still ahead', () {
      const state = CreateMemoryState(occasionDay: 17, occasionMonth: 9);

      expect(
        state.suggestedUnlockDate(now: DateTime(2026, 9, 2)),
        DateTime(2026, 9, 17),
      );
    });

    /// The field refuses anything not in the future, so a prefill that lands
    /// in the past would arrive already rejected.
    test('rolls to next year when this year has gone', () {
      const state = CreateMemoryState(occasionDay: 17, occasionMonth: 7);

      expect(
        state.suggestedUnlockDate(now: DateTime(2026, 9, 2)),
        DateTime(2027, 7, 17),
      );
    });

    /// A date is midnight and the field compares against `now`, so today is
    /// already behind us.
    test('treats today as gone', () {
      const state = CreateMemoryState(occasionDay: 2, occasionMonth: 9);

      expect(
        state.suggestedUnlockDate(now: DateTime(2026, 9, 2, 14, 30)),
        DateTime(2027, 9, 2),
      );
    });
  });

  group('suggestUnlockDate', () {
    ProviderContainer build() {
      final container = ProviderContainer(
        overrides: [
          memoriesRepositoryProvider.overrideWithValue(
            FakeMemoriesRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('fills the blank from the occasion', () {
      final container = build();
      final notifier = container.read(createMemoryProvider.notifier)
        ..setOccasionDay(25)
        ..setOccasionMonth(12);

      notifier.suggestUnlockDate();

      final suggested = container.read(createMemoryProvider).unlockDate!;
      expect(suggested.day, 25);
      expect(suggested.month, 12);
    });

    test('never overwrites a date the host picked', () {
      final container = build();
      final notifier = container.read(createMemoryProvider.notifier)
        ..setUnlockDate(DateTime(2027, 1, 1));

      notifier.suggestUnlockDate();

      expect(
        container.read(createMemoryProvider).unlockDate,
        DateTime(2027, 1, 1),
      );
    });

    /// Going back, changing the occasion and coming forward again should
    /// follow the change rather than leaving the first guess behind.
    test('re-derives when only the occasion changed', () {
      final container = build();
      final notifier = container.read(createMemoryProvider.notifier)
        ..setOccasionMonth(12)
        ..setOccasionDay(25);
      notifier.suggestUnlockDate();

      notifier
        ..setOccasionMonth(11)
        ..setOccasionDay(5);
      notifier.suggestUnlockDate();

      final suggested = container.read(createMemoryProvider).unlockDate!;
      expect(suggested.day, 5);
      expect(suggested.month, 11);
    });

    /// Clearing the box is a choice too — the suggestion must not creep back.
    test('stays out of the way once the box has been cleared', () {
      final container = build();
      final notifier = container.read(createMemoryProvider.notifier)
        ..setUnlockDate(DateTime(2027, 1, 1))
        ..clearUnlockDate();

      notifier.suggestUnlockDate();

      expect(container.read(createMemoryProvider).unlockDate, isNull);
    });
  });

  testWidgets('step 2 opens with the occasion date already in the box', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        memoriesRepositoryProvider.overrideWithValue(FakeMemoriesRepository()),
        wishmatesRepositoryProvider.overrideWithValue(
          FakeWishmatesRepository(mates: [buildWishmate()]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(createMemoryProvider.notifier)
      ..setOccasionDay(25)
      ..setOccasionMonth(12);
    notifier.suggestUnlockDate();
    final expected = container.read(createMemoryProvider).unlockDate!;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CreateMemoryUnlockScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('25/12/${expected.year}'), findsOneWidget);
  });
}
