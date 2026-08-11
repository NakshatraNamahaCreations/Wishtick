import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/chat/data/chat_repository.dart';
import 'package:wishtick_flutter/features/chat/data/chat_socket.dart';
import 'package:wishtick_flutter/features/chat/domain/chat_message.dart';
import 'package:wishtick_flutter/features/chat/presentation/chat_controller.dart';

import '../../helpers/chat_fakes.dart';

void main() {
  late FakeChatRepository repo;
  late FakeChatSocket socket;
  late ProviderContainer container;

  ProviderContainer build(FakeChatRepository r, [FakeChatSocket? s]) =>
      ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(r),
          chatSocketProvider.overrideWithValue(s ?? FakeChatSocket()),
        ],
      );

  setUp(() {
    repo = FakeChatRepository(
      messages: [
        buildMessage(
          id: 'm3',
          body: 'newest',
          createdAt: DateTime(2026, 8, 1, 12),
        ),
        buildMessage(
          id: 'm2',
          body: 'middle',
          createdAt: DateTime(2026, 8, 1, 11),
        ),
        buildMessage(
          id: 'm1',
          body: 'oldest',
          createdAt: DateTime(2026, 8, 1, 10),
        ),
      ],
    );
    socket = FakeChatSocket();
    container = build(repo, socket);
  });

  tearDown(() => container.dispose());

  ChatController notifier([String id = 'chat_1']) =>
      container.read(chatProvider(id).notifier);
  ChatState read([String id = 'chat_1']) => container.read(chatProvider(id));

  test('history is flipped to oldest-first, the order it is read in', () async {
    await notifier().load();

    expect(read().messages.map((m) => m.id), ['m1', 'm2', 'm3']);
  });

  test('opening the chat marks it read', () async {
    await notifier().load();
    expect(repo.calls, contains('markRead'));
  });

  test('a failing markRead does not blank the screen', () async {
    // The load succeeds, then read-marking fails. The conversation must still
    // be on screen — a lingering unread badge is a nuisance, an empty chat is
    // not.
    repo.markReadFails = true;
    await notifier().load();
    await Future<void>.delayed(Duration.zero);

    expect(read().messages, isNotEmpty);
    expect(read().error, isNull);
  });

  test('joins the room and reports the connection', () async {
    await notifier().load();
    await Future<void>.delayed(Duration.zero);

    expect(socket.joined, ['chat_1']);
    expect(read().connected, isTrue);
  });

  test('a pushed message lands in the conversation', () async {
    await notifier().load();
    socket.emit(ChatMessageEvent(buildMessage(id: 'm4', body: 'live')));
    await Future<void>.delayed(Duration.zero);

    expect(read().messages.last.id, 'm4');
  });

  test(
    'an echo of a message already held replaces it, not duplicates it',
    () async {
      await notifier().load();
      final before = read().messages.length;

      socket.emit(ChatMessageEvent(buildMessage(id: 'm2', body: 'edited')));
      await Future<void>.delayed(Duration.zero);

      expect(read().messages, hasLength(before));
      expect(read().messages.firstWhere((m) => m.id == 'm2').body, 'edited');
    },
  );

  test('traffic for another chat is ignored', () async {
    await notifier().load();
    final before = read().messages.length;

    socket.emit(
      ChatMessageEvent(buildMessage(id: 'other', chatId: 'chat_999')),
    );
    await Future<void>.delayed(Duration.zero);

    expect(read().messages, hasLength(before));
  });

  test(
    'a dropped socket is reported rather than silently going stale',
    () async {
      await notifier().load();
      socket.emit(const ChatConnectionEvent(false));
      await Future<void>.delayed(Duration.zero);

      expect(read().connected, isFalse);
    },
  );

  test('loadMore prepends the older page', () async {
    repo.nextCursor = 'm1';
    await notifier().load();
    expect(read().hasMore, isTrue);

    repo.messages = [
      buildMessage(id: 'm0', body: 'ancient', createdAt: DateTime(2026, 7, 31)),
    ];
    repo.nextCursor = null;
    await notifier().loadMore();

    expect(read().messages.first.id, 'm0');
    expect(read().hasMore, isFalse);
    expect(repo.calls, contains('listMessages:m1'));
  });

  test('sending posts over REST and splices the result in', () async {
    await notifier().load();
    final ok = await notifier().send('  hello  ');

    expect(ok, isTrue);
    // Trimmed on the way out.
    expect(repo.calls, contains('postMessage:hello'));
    expect(read().messages.last.id, 'posted');
  });

  test('an empty message is not sent', () async {
    await notifier().load();
    expect(await notifier().send('   '), isFalse);
    expect(repo.calls.where((c) => c.startsWith('postMessage')), isEmpty);
  });

  test('a rate limit is said in plain words', () async {
    await notifier().load();
    repo.failWith = const ApiException(
      code: 'CHAT_RATE_LIMITED',
      message: 'raw',
    );

    expect(await notifier().send('spam'), isFalse);
    expect(read().error, 'Slow down a moment, then try again.');
  });

  test('reacting replaces the message rather than appending it', () async {
    await notifier().load();
    final before = read().messages.length;

    await notifier().react('m2', '❤️');

    expect(read().messages, hasLength(before));
    final updated = read().messages.firstWhere((m) => m.id == 'm2');
    expect(updated.reactions.single.emoji, '❤️');
  });

  test('deleting keeps the envelope and empties the body', () async {
    await notifier().load();
    await notifier().deleteMessage('m2');

    final deleted = read().messages.firstWhere((m) => m.id == 'm2');
    expect(deleted.isDeleted, isTrue);
    expect(deleted.body, isEmpty);
    // Still three: replies to it must not dangle.
    expect(read().messages, hasLength(3));
  });

  test('a failed load surfaces the message', () async {
    final r = FakeChatRepository(
      failWith: const ApiException(code: 'X', message: 'Chat is unavailable'),
    );
    final c = build(r);
    addTearDown(c.dispose);

    await c.read(chatProvider('chat_1').notifier).load();

    expect(c.read(chatProvider('chat_1')).error, 'Chat is unavailable');
    expect(c.read(chatProvider('chat_1')).chat, isNull);
  });

  group('system messages', () {
    test('carry a typed kind and a payload, not a parsed string', () {
      final m = buildSystemMessage(
        type: SystemMessageType.contributionReceived,
        payload: {
          'actorName': 'Rohan',
          'amountMinor': 100000,
          'collectedAmountMinor': 100000,
          'targetAmountMinor': 1699900,
        },
      );

      expect(m.isSystem, isTrue);
      expect(m.senderId, isNull);
      expect(m.payloadString('actorName'), 'Rohan');
      expect(m.payloadAmountMinor('amountMinor'), 100000);
    });

    test('an unrecognised type still parses rather than throwing', () {
      final m = ChatMessage.fromJson({
        'id': 'x',
        'chatId': 'chat_1',
        'kind': 'system',
        'body': 'Something new happened',
        'systemType': 'a_type_from_the_future',
        'createdAt': '2026-08-01T10:00:00.000Z',
      });

      expect(m.systemType, SystemMessageType.unknown);
      // The server's own text is the fallback, so the card is never blank.
      expect(m.body, 'Something new happened');
    });

    test('a missing payload field reads as null, not zero', () {
      final m = buildSystemMessage(payload: {'actorName': 'Sona'});
      expect(m.payloadAmountMinor('amountMinor'), isNull);
    });
  });
}
