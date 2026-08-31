import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/group_gift/data/group_gift_repository.dart';
import 'package:wishtick_flutter/features/group_gift/domain/group_gift.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/contribution_success_screen.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_details_screen.dart';

import '../../helpers/group_gift_fakes.dart';

/// "Thank You!" (`316:298`) — what a contributor sees after pledging.
///
/// The frame is drawn for a payment that completed in-app. It has not, so this
/// screen carries the one fact a contributor cannot afford to lose: whose
/// account to send the money to. It used to be a snackbar, which took the
/// answer away again seconds later with nothing else on any screen showing it.
void main() {
  Future<void> pump(
    WidgetTester tester,
    ContributionReceipt receipt, {
    ThemeData? theme,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: ContributionSuccessScreen(receipt: receipt),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('names the host, not just their handle', (tester) async {
    await pump(tester, (
      amountMinor: 100000,
      hostName: 'Rohan',
      hostUpiId: 'myupi@icic.com',
    ));

    // Both halves. The handle alone does not tell the sender whose account
    // they are about to pay, and the name alone is not payable.
    expect(find.text('Now send ₹1,000 to Rohan'), findsOneWidget);
    expect(find.text('myupi@icic.com'), findsOneWidget);
    expect(
      find.text('Your Contribution of ₹1,000 was successful.'),
      findsOneWidget,
    );
  });

  testWidgets('copies the handle so it need not be retyped', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(tester, (
      amountMinor: 100000,
      hostName: 'Rohan',
      hostUpiId: 'myupi@icic.com',
    ));
    await tester.tap(find.text('Copy UPI ID'));
    await tester.pump();

    // The handle, not the sentence around it — pasting "Now send ₹1,000 to
    // Rohan" into a UPI app pays nobody.
    expect(copied, ['myupi@icic.com']);
  });

  // A group gift created without a UPI ID. Saying nothing would read as though
  // the money had already moved.
  testWidgets('says the host will share it when there is no handle', (
    tester,
  ) async {
    await pump(tester, (
      amountMinor: 100000,
      hostName: 'Rohan',
      hostUpiId: null,
    ));

    expect(find.text('The host will share where to send it.'), findsOneWidget);
    expect(find.text('Copy UPI ID'), findsNothing);
  });

  testWidgets('still payable when the server could not name the host', (
    tester,
  ) async {
    await pump(tester, (
      amountMinor: 100000,
      hostName: null,
      hostUpiId: 'myupi@icic.com',
    ));

    expect(find.text('Now send ₹1,000 to the host'), findsOneWidget);
    expect(find.text('myupi@icic.com'), findsOneWidget);
  });

  testWidgets('renders on a dark page', (tester) async {
    await pump(tester, (
      amountMinor: 100000,
      hostName: 'Rohan',
      hostUpiId: 'myupi@icic.com',
    ), theme: AppTheme.dark);

    expect(tester.takeException(), isNull);
    expect(find.text('Thank You!'), findsOneWidget);
  });

  // The handoff. Everything above is worthless if the details screen never
  // sends the host's details across.
  group('from the details screen', () {
    testWidgets('a pledge opens the confirmation carrying who to pay', (
      tester,
    ) async {
      final gift = buildGroupGift(
        hostId: 'host_1',
        hostUpiId: 'myupi@icic.com',
        participants: const [
          GroupGiftParticipant(userId: 'host_1', name: 'Rohan'),
          GroupGiftParticipant(userId: 'user_2', name: 'Sona'),
        ],
      );
      final router = GoRouter(
        initialLocation: '/group-gifts/gg_1',
        routes: [
          GoRoute(
            path: '/group-gifts/:id',
            builder: (_, _) =>
                const GroupGiftDetailsScreen(groupGiftId: 'gg_1'),
            routes: [
              GoRoute(
                path: 'contributed',
                builder: (_, state) => ContributionSuccessScreen(
                  receipt: state.extra! as ContributionReceipt,
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            groupGiftRepositoryProvider.overrideWithValue(
              FakeGroupGiftRepository(gift: gift),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chip In'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('₹1,000'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Pay '));
      await tester.pumpAndSettle();

      // The host's *name*, which only the participant list knows — proving the
      // details screen resolved it rather than passing the raw id through.
      expect(find.text('Now send ₹1,000 to Rohan'), findsOneWidget);
      expect(find.text('myupi@icic.com'), findsOneWidget);
    });
  });
}
