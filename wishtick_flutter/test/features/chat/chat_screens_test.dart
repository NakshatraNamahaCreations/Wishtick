import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/chat/data/chat_repository.dart';
import 'package:wishtick_flutter/features/chat/data/chat_socket.dart';
import 'package:wishtick_flutter/features/chat/domain/chat_message.dart';
import 'package:wishtick_flutter/features/chat/presentation/group_chat_screen.dart';
import 'package:wishtick_flutter/features/group_gift/data/group_gift_repository.dart';
import 'package:wishtick_flutter/features/group_gift/domain/group_gift.dart';
import 'package:wishtick_flutter/features/group_gift/presentation/group_gift_thank_you_screen.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/group_gift_fakes.dart';

void main() {
  Future<void> pumpChat(
    WidgetTester tester, {
    required FakeChatRepository chat,
    GroupGift? gift,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(chat),
          chatSocketProvider.overrideWithValue(FakeChatSocket()),
          groupGiftRepositoryProvider.overrideWithValue(
            FakeGroupGiftRepository(
              gift:
                  gift ??
                  buildGroupGift(
                    collectedAmountMinor: 100000,
                    participants: const [
                      GroupGiftParticipant(userId: 'host_1', name: 'Rohan'),
                      GroupGiftParticipant(userId: 'user_2', name: 'Sona'),
                    ],
                  ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: const GroupChatScreen(groupGiftId: 'gg_1', chatId: 'chat_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Group Chat', () {
    testWidgets('the header carries the funding progress', (tester) async {
      await pumpChat(tester, chat: FakeChatRepository());

      expect(find.text('Group Chat'), findsOneWidget);
      expect(find.text("Siya's birthday gift"), findsOneWidget);
      expect(find.text('2 Members'), findsOneWidget);
      // ₹1,000 of the ₹17,347 Grand Total.
      expect(find.textContaining('₹1,000 of ₹17,347'), findsOneWidget);
    });

    testWidgets('a system message renders from its type, not its body', (
      tester,
    ) async {
      await pumpChat(
        tester,
        chat: FakeChatRepository(
          messages: [
            buildSystemMessage(
              type: SystemMessageType.contributionReceived,
              // Deliberately blank: the card must not depend on server prose.
              body: '',
              // The real payload shape: an id, resolved against the group's
              // participant list. It never carries a name.
              payload: {
                'contributorId': 'host_1',
                'anonymous': false,
                'amountMinor': 100000,
                'collectedAmountMinor': 100000,
                'targetAmountMinor': 1699900,
              },
            ),
          ],
        ),
      );

      expect(find.text('Rohan Paid ₹1,000'), findsOneWidget);
      expect(
        find.textContaining('Goal Updated  ₹1,000 of ₹16,999'),
        findsOneWidget,
      );
    });

    testWidgets('an anonymous contribution is not attributed', (tester) async {
      await pumpChat(
        tester,
        chat: FakeChatRepository(
          messages: [
            buildSystemMessage(
              type: SystemMessageType.contributionReceived,
              payload: {
                // Redacted server-side; the card must not invent a name.
                'contributorId': null,
                'anonymous': true,
                'amountMinor': 50000,
              },
            ),
          ],
        ),
      );

      expect(find.text('Someone Paid ₹500'), findsOneWidget);
    });

    testWidgets('an unknown system type still shows something', (tester) async {
      await pumpChat(
        tester,
        chat: FakeChatRepository(
          messages: [
            buildSystemMessage(
              type: SystemMessageType.unknown,
              body: 'Something new happened',
            ),
          ],
        ),
      );

      expect(find.text('Something new happened'), findsOneWidget);
    });

    testWidgets('a deleted message keeps its place and says so', (
      tester,
    ) async {
      await pumpChat(
        tester,
        chat: FakeChatRepository(
          messages: [
            buildMessage(id: 'gone', body: '', deletedAt: DateTime(2026, 8, 1)),
          ],
        ),
      );

      expect(find.text('This message was deleted'), findsOneWidget);
    });

    testWidgets('a reaction shows its emoji and count', (tester) async {
      await pumpChat(
        tester,
        chat: FakeChatRepository(
          messages: [
            buildMessage(
              reactions: const [
                MessageReaction(emoji: '❤️', count: 2, userIds: ['a', 'b']),
              ],
            ),
          ],
        ),
      );

      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('a read-only chat says so instead of offering a composer', (
      tester,
    ) async {
      await pumpChat(
        tester,
        chat: FakeChatRepository(chat: buildChat(whoCanPost: 'moderators')),
      );

      expect(find.text('You cannot post here'), findsOneWidget);
    });

    testWidgets('typing and sending clears the composer', (tester) async {
      final chat = FakeChatRepository();
      await pumpChat(tester, chat: chat);

      await tester.enterText(find.byType(TextField), 'Siya likes blue');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(chat.calls, contains('postMessage:Siya likes blue'));
      expect(find.text('Siya likes blue'), findsOneWidget);
    });

    for (final theme in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
      testWidgets('renders in ${theme.key}', (tester) async {
        await pumpChat(
          tester,
          chat: FakeChatRepository(
            messages: [
              buildMessage(),
              buildSystemMessage(
                type: SystemMessageType.groupGiftStarted,
                body: 'Rohan created this group',
              ),
            ],
          ),
          theme: theme.value,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Thank you', () {
    Future<void> pumpThankYou(
      WidgetTester tester, {
      required GroupGift gift,
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupGiftRepositoryProvider.overrideWithValue(
              FakeGroupGiftRepository(gift: gift),
            ),
          ],
          child: MaterialApp(
            theme: theme ?? AppTheme.light,
            home: const GroupGiftThankYouScreen(groupGiftId: 'gg_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the note on the card', (tester) async {
      await pumpThankYou(
        tester,
        gift: buildGroupGift(
          status: GroupGiftStatus.fulfilled,
          thankYouNote: "I've wanted this for so long.",
        ),
      );

      expect(find.text('Thank\nYou'), findsOneWidget);
      expect(find.text('Dear family & friends,'), findsOneWidget);
      expect(find.text("I've wanted this for so long."), findsOneWidget);
    });

    testWidgets('an open gift offers nothing to write yet', (tester) async {
      await pumpThankYou(tester, gift: buildGroupGift());

      expect(find.text('No thank-you note yet.'), findsOneWidget);
      expect(find.text('Write a thank-you note'), findsNothing);
    });

    testWidgets('a bought gift invites the recipient to write', (tester) async {
      await pumpThankYou(
        tester,
        gift: buildGroupGift(status: GroupGiftStatus.purchased),
      );

      expect(find.text('Write a thank-you note'), findsOneWidget);
    });

    testWidgets('the host is not offered the recipient\'s note', (
      tester,
    ) async {
      await pumpThankYou(
        tester,
        gift: buildGroupGift(
          status: GroupGiftStatus.purchased,
          // A share block is what marks the caller as the host.
          share: const GroupGiftShare(
            slug: 's',
            url: 'u',
            hasPasscode: false,
          ),
        ),
      );

      expect(find.text('Write a thank-you note'), findsNothing);
    });

    testWidgets('renders in dark', (tester) async {
      await pumpThankYou(
        tester,
        gift: buildGroupGift(
          status: GroupGiftStatus.fulfilled,
          thankYouNote: 'Thank you all!',
        ),
        theme: AppTheme.dark,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
