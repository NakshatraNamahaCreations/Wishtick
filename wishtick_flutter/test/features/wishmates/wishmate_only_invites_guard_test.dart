import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Invitations are addressed to WishMates, and to nobody else.
///
/// Email and phone invites were removed on purpose: an address invite creates a
/// row bound to nobody, which then has to be linked up if a matching signup
/// ever arrives, and which shows on the host's guest list as whatever string
/// was typed. Anybody outside the graph is reached with a share link instead —
/// that makes them an account first and a guest second.
///
/// This is a source scan rather than a behavioural test because the failure it
/// guards against is *reintroduction*: a new screen with an "invite by email"
/// field would pass every existing test while quietly restoring the shape. The
/// three call sites below are the ones that would need it, so they are the
/// ones watched.
void main() {
  String read(String path) {
    final file = File(path);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          '$path has moved. Point this guard at its new home rather than '
          'deleting it — the rule it keeps did not move.',
    );
    return file.readAsStringSync();
  }

  test('nothing sends an email or phone as an invite recipient', () {
    const watched = [
      'lib/features/events/data/events_repository.dart',
      'lib/features/wishlist/data/wishlist_repository.dart',
      'lib/core/dev/dev_repositories.dart',
    ];

    for (final path in watched) {
      final source = read(path);
      expect(
        source,
        isNot(contains('inviteEmail')),
        reason:
            '$path invites by email address again. Sharing goes through the '
            'WishMates picker; a stranger joins with the share link.',
      );
    }
  });

  test('the events repository invites by user id only', () {
    final source = read('lib/features/events/data/events_repository.dart');

    expect(source, contains('inviteWishmates'));
    // The old bulk endpoint took `({String? email, String? phone, String? name})`.
    // Its absence is the assertion — a recipient record with any of those keys
    // is the exact shape being kept out.
    expect(source, isNot(contains("'email':")));
    expect(source, isNot(contains("'phone':")));
    expect(
      source,
      isNot(contains('resend')),
      reason:
          'Resend only meant something when an invite was delivered by mail. '
          'There is no channel to resend on.',
    );
  });

  test('the wishlist repository requires an account to share with', () {
    final source = read('lib/features/wishlist/data/wishlist_repository.dart');

    expect(
      source,
      contains('required String userId'),
      reason:
          'Making userId optional again is how an address invite gets back '
          'in: the server would then need a second identifier to accept.',
    );
  });
}
