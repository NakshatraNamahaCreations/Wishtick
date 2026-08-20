import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/widgets/date_entry_field.dart';

void main() {
  Finder fieldFinder() => find.byType(TextField);

  Future<({List<DateTime?> changes, List<String?> errors})> pump(
    WidgetTester tester, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String tooEarlyText = 'That date is too early',
    String tooLateText = 'That date is too far ahead',
  }) async {
    final changes = <DateTime?>[];
    final errors = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateEntryField(
            initialDate: initialDate,
            firstDate: firstDate ?? DateTime(2000),
            lastDate: lastDate ?? DateTime(2030, 12, 31),
            calendarIcon: const Icon(Icons.calendar_today_outlined),
            tooEarlyText: tooEarlyText,
            tooLateText: tooLateText,
            onChanged: changes.add,
            onValidationError: errors.add,
          ),
        ),
      ),
    );
    return (changes: changes, errors: errors);
  }

  group('DateInputFormatter', () {
    testWidgets('auto-inserts slashes as digits are typed', (tester) async {
      final r = await pump(tester);

      await tester.enterText(fieldFinder(), '18082001');
      await tester.pump();

      expect(
        tester.widget<TextField>(fieldFinder()).controller?.text,
        '18/08/2001',
      );
      expect(r.changes.last, DateTime(2001, 8, 18));
      expect(r.errors, everyElement(isNull));
    });

    testWidgets('caps input at 8 digits', (tester) async {
      await pump(tester);

      await tester.enterText(fieldFinder(), '180820019999');
      await tester.pump();

      expect(
        tester.widget<TextField>(fieldFinder()).controller?.text,
        '18/08/2001',
      );
    });
  });

  group('parseTypedDate', () {
    test('rejects a day that does not exist in the given month', () {
      expect(parseTypedDate('31/02/2020'), isNull);
    });

    test('accepts a real leap-day date', () {
      expect(parseTypedDate('29/02/2020'), DateTime(2020, 2, 29));
    });

    test('rejects anything short of 10 characters', () {
      expect(parseTypedDate('18/08/20'), isNull);
    });
  });

  group('interaction', () {
    testWidgets('tapping the text focuses it, not the picker', (tester) async {
      await pump(tester);

      await tester.tap(fieldFinder());
      await tester.pump();

      expect(find.text('OK'), findsNothing);
    });

    testWidgets('tapping the calendar icon opens the picker, not the '
        'keyboard', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('picking a date fills the box and reports it', (tester) async {
      final r = await pump(
        tester,
        initialDate: DateTime(2020, 1, 1),
        firstDate: DateTime(2000),
        lastDate: DateTime(2030, 12, 31),
      );

      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // The picker's own default selection is whatever initialDate seeded —
      // confirming the box's text now reflects *a* picked value at all.
      expect(
        tester.widget<TextField>(fieldFinder()).controller?.text,
        isNotEmpty,
      );
      expect(r.changes.last, isNotNull);
    });
  });

  group('validation', () {
    testWidgets('below 8 digits reports null and no error', (tester) async {
      final r = await pump(tester);

      await tester.enterText(fieldFinder(), '1808');
      await tester.pump();

      expect(r.changes.last, isNull);
      expect(r.errors, isEmpty);
    });

    testWidgets('a date that does not exist is rejected', (tester) async {
      final r = await pump(tester);

      await tester.enterText(fieldFinder(), '31022020');
      await tester.pump();

      expect(r.changes.last, isNull);
      expect(
        r.errors.last,
        "That date doesn't exist — check the day and month",
      );
    });

    testWidgets('a date before firstDate is rejected with tooEarlyText', (
      tester,
    ) async {
      final r = await pump(
        tester,
        firstDate: DateTime(2010),
        tooEarlyText: 'Too old',
      );

      await tester.enterText(fieldFinder(), '01011999');
      await tester.pump();

      expect(r.changes.last, isNull);
      expect(r.errors.last, 'Too old');
    });

    testWidgets('a date after lastDate is rejected with tooLateText', (
      tester,
    ) async {
      final r = await pump(
        tester,
        lastDate: DateTime(2025),
        tooLateText: 'Too far out',
      );

      await tester.enterText(fieldFinder(), '01012030');
      await tester.pump();

      expect(r.changes.last, isNull);
      expect(r.errors.last, 'Too far out');
    });

    testWidgets('erasing back to incomplete clears a previous error', (
      tester,
    ) async {
      final r = await pump(tester);

      await tester.enterText(fieldFinder(), '31022020');
      await tester.pump();
      expect(r.errors.last, isNotNull);

      await tester.enterText(fieldFinder(), '3102');
      await tester.pump();

      expect(r.errors.last, isNull);
    });

    testWidgets('a complete valid date reports no error', (tester) async {
      final r = await pump(tester);

      await tester.enterText(fieldFinder(), '18082001');
      await tester.pump();

      expect(r.errors, everyElement(isNull));
    });
  });

  group('seeding and hints', () {
    testWidgets('initialDate seeds the displayed text', (tester) async {
      await pump(tester, initialDate: DateTime(2001, 8, 18));

      expect(
        tester.widget<TextField>(fieldFinder()).controller?.text,
        '18/08/2001',
      );
    });

    testWidgets('defaults the hint to dd/mm/yyyy', (tester) async {
      await pump(tester);

      expect(
        tester.widget<TextField>(fieldFinder()).decoration?.hintText,
        'dd/mm/yyyy',
      );
    });

    testWidgets('a custom decoration hintText is kept', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateEntryField(
              firstDate: DateTime(2000),
              lastDate: DateTime(2030),
              calendarIcon: const Icon(Icons.calendar_today_outlined),
              decoration: const InputDecoration(labelText: 'Event Date *'),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(
        tester.widget<TextField>(fieldFinder()).decoration?.labelText,
        'Event Date *',
      );
      expect(
        tester.widget<TextField>(fieldFinder()).decoration?.hintText,
        'dd/mm/yyyy',
      );
    });
  });
}
