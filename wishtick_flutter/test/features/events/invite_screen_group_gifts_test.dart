import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/events/data/invite_repository.dart';
import 'package:wishtick_flutter/features/events/domain/public_invite.dart';
import 'package:wishtick_flutter/features/events/presentation/invite_screen.dart';

import '../../helpers/gifting_fakes.dart';

/// `291:1008`'s "Group Gifts · 1 active gift" row.
///
/// The frame has always drawn it; the screen omitted it because nothing linked
/// a group gift to an event. A gift now carries the event its wishlist was
/// attached to, stamped when the group is created.
void main() {
  late FakeInviteRepository repo;

  setUp(() => repo = FakeInviteRepository());

  Future<void> pump(WidgetTester tester, PublicInvite invite) async {
    tester.view
      ..physicalSize = const Size(393, 1600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    repo.invite = invite;
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [inviteRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const InviteScreen(token: 'tok_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a running group gift appears with its count', (tester) async {
    await pump(
      tester,
      buildInvite(
        groupGifts: const [
          InviteGroupGift(id: 'gg_1', title: 'Telescope fund'),
        ],
      ),
    );

    expect(find.text('Group Gifts'), findsOneWidget);
    expect(find.text('1 active gift'), findsOneWidget);
  });

  testWidgets('several are counted, not listed one row each', (tester) async {
    await pump(
      tester,
      buildInvite(
        groupGifts: const [
          InviteGroupGift(id: 'gg_1', title: 'Telescope fund'),
          InviteGroupGift(id: 'gg_2', title: 'Camera fund'),
        ],
      ),
    );

    // One row that says how many, as the frame draws it — not a row per gift,
    // which would push the rest of Quick Suggestions off the screen.
    expect(find.text('Group Gifts'), findsOneWidget);
    expect(find.text('2 active gifts'), findsOneWidget);
  });

  testWidgets('no running group means no row at all', (tester) async {
    await pump(tester, buildInvite());

    // An invitee cannot start a group from here, so an empty row would be an
    // affordance for nothing.
    expect(find.text('Group Gifts'), findsNothing);
  });

  test('the invite carries only what an invitee may see of a group', () {
    // Id and title. Amounts, participants and who has paid are the group's own
    // business and stay behind its endpoint — an invite token is not
    // membership.
    const gift = InviteGroupGift(id: 'gg_1', title: 'Telescope fund');
    expect(gift.id, 'gg_1');
    expect(gift.title, 'Telescope fund');

    final parsed = InviteGroupGift.fromJson(const {
      'id': 'gg_2',
      'title': 'Camera fund',
      'targetAmountMinor': 500000,
      'collectedMinor': 250000,
    });
    expect(parsed.id, 'gg_2');
    expect(parsed.title, 'Camera fund');
  });
}
