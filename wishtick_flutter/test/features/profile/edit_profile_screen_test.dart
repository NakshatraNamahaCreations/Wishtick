import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/profile/data/profile_repository.dart';
import 'package:wishtick_flutter/features/profile/presentation/edit_profile_screen.dart';

import '../../helpers/profile_fakes.dart';

void main() {
  Finder fieldWithHint(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );

  Future<FakeProfileRepository> pump(WidgetTester tester) async {
    final repo = FakeProfileRepository();
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EditProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  group('Date of Birth', () {
    testWidgets('opens seeded with the loaded profile\'s date', (tester) async {
      await pump(tester);

      expect(
        tester.widget<TextField>(fieldWithHint('dd/mm/yyyy')).controller?.text,
        '01/01/2000',
      );
    });

    testWidgets('tapping the box focuses it, not the calendar', (tester) async {
      await pump(tester);

      // The form gained a row above this one, so it starts below the fold:
      // a tap outside the viewport is silently dropped.
      await tester.ensureVisible(fieldWithHint('dd/mm/yyyy'));
      await tester.pumpAndSettle();
      await tester.tap(fieldWithHint('dd/mm/yyyy'));
      await tester.pump();

      expect(find.text('OK'), findsNothing);
    });

    testWidgets('only the calendar icon opens the picker', (tester) async {
      await pump(tester);

      await tester.ensureVisible(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('a typed date that does not exist is called out', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(fieldWithHint('dd/mm/yyyy'), '31022020');
      await tester.pump();

      expect(
        find.text("That date doesn't exist — check the day and month"),
        findsOneWidget,
      );
    });
  });
}
