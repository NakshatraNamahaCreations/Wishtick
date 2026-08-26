import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mechanically enforces that every cache belonging to a session is dropped
/// when that session ends.
///
/// A provider that is not `autoDispose` outlives the screens reading it, so one
/// left off `invalidateSessionScopedProviders` keeps the previous user's data
/// after a sign-out — their profile, wishlists, notifications, messages —
/// until something happens to refetch. That is a disclosure bug, and the kind
/// nobody notices for months, because the app looks right on the *first* login
/// of every session. A reviewer cannot be relied on to spot the omission; a
/// failing test can.
///
/// If this fails, add the provider to
/// `lib/features/auth/presentation/session_scoped_providers.dart` — or make it
/// `autoDispose`, which solves the same problem by a different route.
void main() {
  const clearingFile =
      'lib/features/auth/presentation/session_scoped_providers.dart';

  /// Providers that must NOT be cleared, with the reason.
  const exempt = {
    // The controller doing the clearing. Invalidating it mid-sign-out would
    // discard the signed-out state it has just set.
    'sessionProvider',
    // The controller that *calls* `accept()`. Clearing it from there would
    // dispose it while it is still awaiting its own sign-in call.
    'signInControllerProvider',
  };

  /// Declarations like `final fooProvider = FutureProvider<...>((ref) {`.
  /// `autoDispose` anywhere in the declaration means it cleans itself up.
  final declaration = RegExp(
    r'^final\s+(\w+Provider)\s*=\s*'
    r'(FutureProvider|StreamProvider|NotifierProvider|AsyncNotifierProvider|StreamNotifierProvider)'
    r'([^;]*)',
    multiLine: true,
  );

  test('every session-scoped provider is cleared when the session ends', () {
    final cleared = File(clearingFile).readAsStringSync();

    final missing = <String>[];
    for (final file
        in Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final match in declaration.allMatches(source)) {
        final name = match.group(1)!;
        // `autoDispose` may sit on the provider or on a `.family` after it, so
        // the whole declaration up to the `;` is what gets checked.
        final isAutoDispose = match.group(3)!.contains('autoDispose');
        if (isAutoDispose || exempt.contains(name)) continue;

        // `ref.invalidate(name)` — not a bare mention, so a stale comment
        // naming the provider cannot satisfy this.
        if (!cleared.contains('ref.invalidate($name)')) {
          missing.add('$name  (${file.path.replaceAll(r'\', '/')})');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'These providers cache data past the session that fetched it, and '
          'nothing clears them on sign-out — so the next user to sign in reads '
          'the previous one\'s data. Add each to $clearingFile, or make it '
          'autoDispose:\n${missing.join('\n')}',
    );
  });

  test('the clearing list names nothing that no longer exists', () {
    final cleared = File(clearingFile).readAsStringSync();
    final sources = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) => f.path.endsWith('.dart') && !f.path.contains('session_scoped'),
        )
        .map((f) => f.readAsStringSync())
        .join('\n');

    final stale = <String>[];
    for (final match in RegExp(
      r'ref\.invalidate\((\w+)\)',
    ).allMatches(cleared)) {
      final name = match.group(1)!;
      if (!sources.contains('final $name =')) stale.add(name);
    }

    expect(
      stale,
      isEmpty,
      reason:
          'Named in $clearingFile but no longer declared anywhere — a rename '
          'or deletion left this behind:\n${stale.join('\n')}',
    );
  });
}
