import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/memories/data/memories_repository.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_unlock_screen.dart';

import '../../helpers/memory_fakes.dart';

void main() {
  Finder fieldWithLabel(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoriesRepositoryProvider.overrideWithValue(
            FakeMemoriesRepository(),
          ),
        ],
        child: const MaterialApp(home: CreateMemoryUnlockScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Unlock Date', () {
    testWidgets('tapping the box focuses it, not the calendar', (tester) async {
      await pump(tester);

      await tester.tap(fieldWithLabel('Unlock Date *'));
      await tester.pump();

      expect(find.text('OK'), findsNothing);
    });

    testWidgets('only the calendar icon opens the picker', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.calendar_today_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('a date in the past is called out', (tester) async {
      await pump(tester);
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final typed =
          '${yesterday.day.toString().padLeft(2, '0')}'
          '${yesterday.month.toString().padLeft(2, '0')}'
          '${yesterday.year}';

      await tester.enterText(fieldWithLabel('Unlock Date *'), typed);
      await tester.pump();

      expect(find.text('That date has already passed'), findsOneWidget);
    });
  });
}
