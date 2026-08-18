import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/notifications/data/notifications_repository.dart';
import 'package:wishtick_flutter/features/notifications/presentation/thank_you_compose_screen.dart';
import 'package:wishtick_flutter/features/notifications/presentation/thank_you_controller.dart';

import '../../helpers/profile_fakes.dart';

void main() {
  /// The server's own default draft, which is what a note opened straight from
  /// a fulfilled gift contains.
  const draftedBody =
      'Dear Rohan Iyer,\n\n'
      'Thank you so much for Nike Air Max Sneakers. It truly means a lot, and '
      "I'm so grateful you thought of me.\n\nWith love,\nAnanya Mehra";

  Future<void> pump(
    WidgetTester tester,
    FakeNotificationsRepository repo,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ThankYouComposeScreen(noteId: 'ty_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Caught on device: the box showed its hint while the counter reported the
  /// drafted body's length, because the controller was seeded on the first
  /// build — when the note was still loading — and never updated.
  testWidgets('fills the box with the server draft once it arrives', (
    tester,
  ) async {
    await pump(
      tester,
      FakeNotificationsRepository(notes: [buildThankYou(body: draftedBody)]),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, draftedBody);
    expect(find.textContaining('Thank you so much for'), findsWidgets);
  });

  /// The counter and the field's own cap must both admit what the server
  /// wrote; 100 would have truncated a 148-character draft on first keystroke.
  test('the message cap admits the server-drafted body', () {
    expect(draftedBody.length, greaterThan(100));
    expect(ThankYouDraft.messageMax, greaterThanOrEqualTo(draftedBody.length));
    // And matches the server's `@MaxLength(2000)`.
    expect(ThankYouDraft.messageMax, 2000);
  });
}
