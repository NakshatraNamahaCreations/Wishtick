import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/profile/data/profile_repository.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';
import 'package:wishtick_flutter/features/wishmates/presentation/username_claim_screen.dart';

import '../../helpers/profile_fakes.dart';
import '../../helpers/wishmates_fakes.dart';

/// The handle-claim screen.
///
/// No frame draws it and every WishMates frame depends on it: an account with
/// no handle cannot be searched for, so this is the gate on the whole sprint.
void main() {
  late FakeWishmatesRepository repo;

  setUp(() => repo = FakeWishmatesRepository());

  Future<void> pump(WidgetTester tester, {ThemeData? theme}) async {
    tester.view
      ..physicalSize = const Size(393, 1200)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          wishmatesRepositoryProvider.overrideWithValue(repo),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: const UsernameClaimScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  final field = find.byType(TextField);

  testWidgets('says plainly what a handle is for', (tester) async {
    await pump(tester);

    expect(find.text('Pick a handle'), findsOneWidget);
    expect(
      find.textContaining('nobody can search for your account'),
      findsOneWidget,
    );
  });

  testWidgets('lower-cases as you type, so the handle on screen is the one '
      'that gets claimed', (tester) async {
    await pump(tester);

    await tester.enterText(field, 'RohanPrasad');
    await tester.pump();

    expect(tester.widget<TextField>(field).controller?.text, 'rohanprasad');
  });

  testWidgets('names the rule it broke, before spending a round trip on it', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(field, 'ab');
    await tester.pump();
    expect(find.text('A handle is at least 3 characters.'), findsOneWidget);

    await tester.enterText(field, 'no spaces!');
    await tester.pump();
    expect(find.text('Letters, numbers and underscore only.'), findsOneWidget);

    // Neither was worth asking the server about.
    expect(repo.calls.any((c) => c.startsWith('isAvailable')), isFalse);
  });

  testWidgets('a locally invalid handle cannot be submitted', (tester) async {
    await pump(tester);

    await tester.enterText(field, 'ab');
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('checks availability once the typing stops, not once per key', (
    tester,
  ) async {
    await pump(tester);

    for (final partial in ['ro', 'roh', 'roha', 'rohan']) {
      await tester.enterText(field, partial);
      await tester.pump(const Duration(milliseconds: 80));
    }
    // Nothing yet: every keystroke restarted the timer.
    expect(repo.calls.any((c) => c.startsWith('isAvailable')), isFalse);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // And exactly one check, for the whole word — not one per prefix.
    expect(repo.calls.where((c) => c.startsWith('isAvailable')).toList(), [
      'isAvailable:rohan',
    ]);
    expect(find.text('@rohan is available.'), findsOneWidget);
  });

  testWidgets('a slow answer for an earlier handle cannot overwrite the one '
      'on screen now', (tester) async {
    repo.pendingAvailability
      ..['aaa'] = Completer<bool>()
      ..['bbb'] = Completer<bool>();
    await pump(tester);

    await tester.enterText(field, 'aaa');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(field, 'bbb');
    await tester.pump(const Duration(milliseconds: 500));

    // The newer answer lands first.
    repo.pendingAvailability['bbb']!.complete(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('@bbb is available.'), findsOneWidget);

    // Then the stale one for a handle that is no longer in the field.
    repo.pendingAvailability['aaa']!.complete(false);
    await tester.pump();
    await tester.pump();

    expect(find.text('@bbb is available.'), findsOneWidget);
    expect(find.textContaining('already taken'), findsNothing);
  });

  testWidgets('a taken handle is called out before submitting', (tester) async {
    repo.usernameAvailable = false;
    await pump(tester);

    await tester.enterText(field, 'taken_one');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('@taken_one is already taken.'), findsOneWidget);
  });

  testWidgets('claims the handle and pops true, so the gate can carry on', (
    tester,
  ) async {
    late bool? popped;
    tester.view
      ..physicalSize = const Size(393, 1200)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wishmatesRepositoryProvider.overrideWithValue(repo),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const UsernameClaimScreen(),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(field, 'rohan_prasad');
    await tester.pump();
    await tester.tap(find.text('Claim Handle'));
    await tester.pumpAndSettle();

    expect(repo.claimedUsername, 'rohan_prasad');
    // `true` is what `openWithHandle` waits for before opening the screen the
    // user actually asked for; anything else means they backed out.
    expect(popped, isTrue);
  });

  testWidgets('a handle taken between the check and the claim is reported '
      'from the code, not guessed from the message', (tester) async {
    await pump(tester);

    await tester.enterText(field, 'rohan_prasad');
    await tester.pump();

    // The availability check said yes; the unique index says otherwise, which
    // is the only answer that actually settles it.
    repo.failWith = const ApiException(
      code: 'USERNAME_TAKEN',
      message: 'some server wording we do not print',
      statusCode: 409,
    );
    await tester.tap(find.text('Claim Handle'));
    await tester.pumpAndSettle();

    expect(find.text('That handle is already taken.'), findsOneWidget);
  });

  testWidgets('a rejected handle explains the rule', (tester) async {
    await pump(tester);

    await tester.enterText(field, 'rohan_prasad');
    await tester.pump();

    repo.failWith = const ApiException(
      code: 'USERNAME_INVALID',
      message: 'nope',
      statusCode: 400,
    );
    await tester.tap(find.text('Claim Handle'));
    await tester.pumpAndSettle();

    expect(find.textContaining('3–30 characters'), findsOneWidget);
  });

  testWidgets('renders on a dark page', (tester) async {
    await pump(tester, theme: AppTheme.dark);

    expect(tester.takeException(), isNull);
  });
}
