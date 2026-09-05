import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/gifting/data/gifting_repository.dart';
import 'package:wishtick_flutter/features/profile/data/profile_repository.dart';
import 'package:wishtick_flutter/features/profile/domain/me.dart';
import 'package:wishtick_flutter/features/profile/presentation/edit_profile_screen.dart';
import 'package:wishtick_flutter/features/profile/presentation/profile_screen.dart';

import '../../helpers/profile_fakes.dart';

/// The `@handle` where the phone number used to be.
///
/// A number is the one thing on the Profile hub its owner cannot act on, and
/// the one thing they would rather not have over their shoulder. A handle is
/// what other people actually find them by.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {Me? me}) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(me: me ?? buildMe()),
          ),
          giftingRepositoryProvider.overrideWithValue(
            FakeGiftListRepository(given: const [], received: const []),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the Profile hub', () {
    testWidgets('shows the handle, and not the phone number', (tester) async {
      await pump(
        tester,
        const ProfileScreen(),
        me: buildMe(username: 'jayanth', phone: '+917829200254'),
      );

      expect(find.text('@jayanth'), findsOneWidget);
      expect(find.text('+917829200254'), findsNothing);
    });

    testWidgets('an account with no handle is offered one, not its number', (
      tester,
    ) async {
      // Falling back to the phone would defeat the point. A handle is the
      // gate on the whole of WishMates, so this is worth asking for.
      await pump(
        tester,
        const ProfileScreen(),
        me: buildMe(username: null, phone: '+917829200254'),
      );

      expect(find.text('Add a username'), findsOneWidget);
      expect(find.text('+917829200254'), findsNothing);
    });
  });

  group('Edit Profile', () {
    testWidgets('shows the handle, locked', (tester) async {
      await pump(
        tester,
        const EditProfileScreen(),
        me: buildMe(username: 'jayanth'),
      );

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('@jayanth'), findsOneWidget);
      expect(find.textContaining('cannot be changed'), findsOneWidget);
      // And it *looks* locked. A box styled like every editable field beside
      // it invites a tap that does nothing, which reads as broken rather than
      // as deliberate.
      final box = tester.widget<InputDecorator>(
        find.ancestor(
          of: find.text('@jayanth'),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(box.decoration.enabled, isFalse);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('it is not a field anybody can type into', (tester) async {
      // Every WishMate link and search result already points at this handle,
      // and nothing behind this screen can rename one.
      await pump(
        tester,
        const EditProfileScreen(),
        me: buildMe(username: 'jayanth'),
      );

      // No text box anywhere holds the handle.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.controller?.text.contains('jayanth') ?? false),
        ),
        findsNothing,
      );
      // The name beside it *is* still a live field, so the screen has not
      // simply gone read-only.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Enter your full name' &&
              // `enabled` is null when the field inherits the default, which
              // is enabled — only an explicit false makes it read-only.
              w.enabled != false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unclaimed handle says so rather than showing a blank box', (
      tester,
    ) async {
      await pump(
        tester,
        const EditProfileScreen(),
        me: buildMe(username: null),
      );

      expect(find.text('Not set yet'), findsOneWidget);
      expect(
        find.textContaining('Claim one from your profile'),
        findsOneWidget,
      );
    });
  });

  group('the handle itself', () {
    test('carries its @, and is null until one is claimed', () {
      expect(buildMe(username: 'jayanth').handle, '@jayanth');
      expect(buildMe(username: null).handle, isNull);
      // An empty string is not a handle either — it would render as a bare @.
      expect(buildMe(username: '').handle, isNull);
    });

    test(
      'the contact line still exists for what is genuinely about contact',
      () {
        expect(buildMe(phone: '+917829200254').contactLine, '+917829200254');
      },
    );
  });
}
