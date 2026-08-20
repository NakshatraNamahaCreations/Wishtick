import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/success_banner.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Duration dwell = const Duration(seconds: 2),
    VoidCallback? onDismissed,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SuccessBanner(
          message: 'Date added successfully!',
          dwell: dwell,
          onDismissed: onDismissed,
        ),
      ),
    ),
  );

  testWidgets('shows the message once its entrance animation settles', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Date added successfully!'), findsOneWidget);
  });

  testWidgets('stays up for the full dwell, not a moment less', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    // Comfortably short of the 2s dwell: still up.
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('Date added successfully!'), findsOneWidget);
  });

  testWidgets('calls onDismissed once the exit animation finishes', (
    tester,
  ) async {
    var dismissed = false;
    await pump(tester, onDismissed: () => dismissed = true);
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 2));
    expect(dismissed, isFalse, reason: 'the exit transition is still running');

    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('a shorter dwell dismisses sooner', (tester) async {
    var dismissed = false;
    await pump(
      tester,
      dwell: const Duration(milliseconds: 500),
      onDismissed: () => dismissed = true,
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });
}
