import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/chat/data/chat_repository.dart';
import 'package:wishtick_flutter/features/chat/data/chat_socket.dart';
import 'package:wishtick_flutter/features/chat/presentation/chat_list_screen.dart';
import 'package:wishtick_flutter/features/chat/presentation/direct_chat_screen.dart';
import 'package:wishtick_flutter/features/chat/presentation/widgets/emoji_picker_sheet.dart';
import 'package:wishtick_flutter/features/profile/data/profile_repository.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';
import 'package:wishtick_flutter/features/wishmates/domain/wishmate.dart';

import '../../helpers/chat_fakes.dart';
import '../../helpers/profile_fakes.dart';
import '../../helpers/wishmates_fakes.dart';

/// The chat list (`4177:179`) and the 1:1 thread (`4177:6`).
void main() {
  late FakeChatRepository chats;
  late FakeWishmatesRepository people;
  late FakeChatSocket socket;

  setUp(() {
    chats = FakeChatRepository();
    people = FakeWishmatesRepository();
    socket = FakeChatSocket();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    ThemeData? theme,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 1600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          chatRepositoryProvider.overrideWithValue(chats),
          wishmatesRepositoryProvider.overrideWithValue(people),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          chatSocketProvider.overrideWithValue(socket),
        ],
        child: MaterialApp(theme: theme ?? AppTheme.light, home: screen),
      ),
    );
    // Not `pumpAndSettle`: the loading state holds a CircularProgressIndicator,
    // which never stops animating.
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  // ── `4177:179` ────────────────────────────────────────────────────────────

  group('Chat list (4177:179)', () {
    testWidgets('names the person from the chat itself — a direct thread’s '
        'refId is a hash and identifies nobody', (tester) async {
      chats.chats = [
        buildDirectChat(
          counterpart: buildIdentity(
            userId: 'u_1',
            displayName: 'Priyal Sharma',
            username: 'priyalsharma',
          ),
          lastMessage: buildPreview(body: 'Hi, please find the invitation'),
        ),
      ];
      await pump(tester, const ChatListScreen());

      expect(find.text('Priyal Sharma'), findsOneWidget);
      expect(find.text('Hi, please find the invitation'), findsOneWidget);
      // The hash must never reach the screen.
      expect(find.textContaining('hash_'), findsNothing);
    });

    testWidgets('summarises several unread rather than quoting only the '
        'newest of them', (tester) async {
      chats.chats = [
        buildDirectChat(
          unreadCount: 4,
          lastMessage: buildPreview(body: 'and one more thing'),
        ),
      ];
      await pump(tester, const ChatListScreen());

      expect(find.text('4+ new messages'), findsOneWidget);
      expect(find.text('and one more thing'), findsNothing);
    });

    testWidgets('a single unread message is quoted, not counted', (
      tester,
    ) async {
      chats.chats = [
        buildDirectChat(unreadCount: 1, lastMessage: buildPreview(body: 'hey')),
      ];
      await pump(tester, const ChatListScreen());

      expect(find.text('hey'), findsOneWidget);
      expect(find.textContaining('new messages'), findsNothing);
    });

    testWidgets('your own last message is quoted like any other — the row is '
        'about the conversation, not about who spoke last', (tester) async {
      chats.chats = [
        buildDirectChat(
          lastMessage: buildPreview(
            senderId: 'u_me',
            body: 'Yes, I’m excited!',
          ),
        ),
      ];
      await pump(tester, const ChatListScreen());

      expect(find.text('Yes, I’m excited!'), findsOneWidget);
    });

    testWidgets('an attachment-only message is described, not left blank', (
      tester,
    ) async {
      chats.chats = [
        buildDirectChat(
          lastMessage: buildPreview(body: '', hasAttachments: true),
        ),
      ];
      await pump(tester, const ChatListScreen());

      expect(find.text('Sent an attachment'), findsOneWidget);
    });

    testWidgets('a thread nobody has written in says so', (tester) async {
      chats.chats = [buildDirectChat(lastMessage: null)];
      await pump(tester, const ChatListScreen());

      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets('search filters by name and by handle', (tester) async {
      chats.chats = [
        buildDirectChat(
          id: 'c1',
          counterpart: buildIdentity(
            userId: 'u_1',
            displayName: 'Priyal Sharma',
            username: 'priyalsharma',
          ),
        ),
        buildDirectChat(
          id: 'c2',
          counterpart: buildIdentity(
            userId: 'u_2',
            displayName: 'Rohan Mehta',
            username: 'rohanm',
          ),
        ),
      ];
      await pump(tester, const ChatListScreen());

      await tester.enterText(find.byType(TextField), 'rohan');
      await tester.pump();

      expect(find.text('Rohan Mehta'), findsOneWidget);
      expect(find.text('Priyal Sharma'), findsNothing);

      await tester.enterText(find.byType(TextField), 'priyalsharma');
      await tester.pump();

      expect(find.text('Priyal Sharma'), findsOneWidget);
      expect(find.text('Rohan Mehta'), findsNothing);
    });

    testWidgets('an empty inbox points at where a conversation starts', (
      tester,
    ) async {
      chats.chats = [];
      await pump(tester, const ChatListScreen());

      expect(find.textContaining('No messages yet'), findsOneWidget);
      expect(find.textContaining('Message to start one'), findsOneWidget);
    });

    testWidgets('a failed load says so instead of spinning', (tester) async {
      chats.failWith = fakeApiFailure;
      await pump(tester, const ChatListScreen());

      expect(find.text('Could not load your messages.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // ── `4177:6` ──────────────────────────────────────────────────────────────

  group('Direct chat (4177:6)', () {
    testWidgets('resolves the thread from the person, and shows their name '
        'and presence in the header', (tester) async {
      chats
        ..chat = buildDirectChat(id: 'chat_d1')
        ..messages = [buildMessage(body: 'Yes, I’m excited!')];
      people.personProfile = buildProfile(
        relationship: WishmateRelationship.wishmates,
        person: buildWishmate(displayName: 'Rohan Prasad', online: true),
      );
      await pump(tester, const DirectChatScreen(userId: 'u_rohan'));

      // Keyed by person, because `POST /chats/direct/:userId` is idempotent.
      expect(chats.directOpens, ['u_rohan']);
      // Twice on purpose: once in the header, once as the bubble's sender.
      expect(find.text('Rohan Prasad'), findsNWidgets(2));
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Yes, I’m excited!'), findsOneWidget);
    });

    testWidgets('refuses politely when you are not WishMates — the connection '
        'is the permission, so this is the rule working', (tester) async {
      chats.failWith = const ApiException(
        code: 'NOT_WISHMATES',
        message: 'You can only message your WishMates.',
        statusCode: 403,
      );
      await pump(tester, const DirectChatScreen(userId: 'u_stranger'));

      expect(find.text('You can only message your WishMates.'), findsOneWidget);
      // Not offered a retry: retrying cannot help, and the button would imply
      // it might.
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Go back'), findsOneWidget);
    });

    testWidgets('any other failure does offer a retry', (tester) async {
      chats.failWith = fakeApiFailure;
      await pump(tester, const DirectChatScreen(userId: 'u_1'));

      expect(find.text('Could not open this conversation.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('the socket dropping outranks their presence — a thread that '
        'stopped updating looks like one nobody is answering', (tester) async {
      chats.chat = buildDirectChat(id: 'chat_d1');
      people.personProfile = buildProfile(
        person: buildWishmate(displayName: 'Rohan Prasad', online: true),
      );
      await pump(tester, const DirectChatScreen(userId: 'u_rohan'));

      // Connected: their real presence shows.
      expect(find.text('Online'), findsOneWidget);

      socket.emit(const ChatConnectionEvent(false));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      // Dropped: the header stops claiming anything about them, because it no
      // longer knows. "Online" beside a dead socket is a lie.
      expect(find.text('Reconnecting…'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('sending posts the message and clears the composer', (
      tester,
    ) async {
      chats.chat = buildDirectChat(id: 'chat_d1');
      await pump(tester, const DirectChatScreen(userId: 'u_rohan'));

      await tester.enterText(find.byType(TextField), 'Awesome, Thank You!');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(chats.calls, contains('postMessage:Awesome, Thank You!'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });

    testWidgets('renders on a dark page', (tester) async {
      chats.chat = buildDirectChat(id: 'chat_d1');
      await pump(
        tester,
        const DirectChatScreen(userId: 'u_rohan'),
        theme: AppTheme.dark,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('the composer', () {
    testWidgets('offers no attach button — nothing was ever behind it', (
      tester,
    ) async {
      chats.chat = buildDirectChat(id: 'chat_d1');
      people.personProfile = buildProfile(
        relationship: WishmateRelationship.wishmates,
        person: buildWishmate(displayName: 'Rohan Prasad'),
      );
      await pump(tester, const DirectChatScreen(userId: 'u_rohan'));

      // It was a bare Icon with no onTap: it looked like an affordance and did
      // nothing when pressed, which is worse than not drawing it.
      expect(find.byIcon(Icons.attach_file), findsNothing);
    });

    testWidgets('the smiley opens the emoji keyboard rather than typing one '
        'fixed character', (tester) async {
      chats.chat = buildDirectChat(id: 'chat_d1');
      people.personProfile = buildProfile(
        relationship: WishmateRelationship.wishmates,
        person: buildWishmate(displayName: 'Rohan Prasad'),
      );
      await pump(tester, const DirectChatScreen(userId: 'u_rohan'));

      await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(EmojiPickerSheet), findsOneWidget);
      // The old behaviour appended a single hardcoded emoji to the field.
      expect(find.text('🙂'), findsNothing);
    });
  });

  testWidgets('the chat list renders on a dark page', (tester) async {
    chats.chats = [buildDirectChat(lastMessage: buildPreview())];
    await pump(tester, const ChatListScreen(), theme: AppTheme.dark);

    expect(tester.takeException(), isNull);
  });
}
