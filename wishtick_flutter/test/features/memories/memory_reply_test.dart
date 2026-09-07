import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/memories/data/memories_repository.dart';
import 'package:wishtick_flutter/features/memories/domain/memory.dart';
import 'package:wishtick_flutter/features/memories/presentation/memory_detail_screen.dart';
import 'package:wishtick_flutter/features/memories/presentation/reply_controller.dart';
import 'package:wishtick_flutter/features/memories/presentation/reply_recipients_screen.dart';

import '../../helpers/memory_fakes.dart';

/// Replying to a memory you were given.
///
/// The direction that did not exist before: a capsule collected wishes and
/// stopped there, so the one person it was all for had no way to answer.
void main() {
  late FakeMemoriesRepository repo;

  setUp(() {
    repo = FakeMemoriesRepository();
  });

  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [memoriesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('the Reply button', () {
    testWidgets('is offered to the person the memory was made for', (
      tester,
    ) async {
      repo.mine = [
        buildCapsule(
          id: 'm1',
          status: MemoryStatus.unlocked,
          isHost: false,
          isRecipient: true,
        ),
      ];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      expect(find.text('Reply to everyone'), findsOneWidget);
    });

    testWidgets('is not offered to the host, who has nobody to answer', (
      tester,
    ) async {
      repo.mine = [buildCapsule(id: 'm1', status: MemoryStatus.unlocked)];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      expect(find.text('Reply to everyone'), findsNothing);
    });

    testWidgets('is not offered while the memory is still sealed', (
      tester,
    ) async {
      // There is nothing to answer until the wishes are readable.
      repo.mine = [buildCapsule(id: 'm1', isHost: false, isRecipient: true)];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      expect(find.text('Reply to everyone'), findsNothing);
    });
  });

  group('replies on the memory screen', () {
    testWidgets('a received reply is shown with its author', (tester) async {
      repo.mine = [buildCapsule(id: 'm1', status: MemoryStatus.unlocked)];
      repo.repliesOnCapsule = [
        buildReply(
          id: 'r1',
          authorName: 'Ananya',
          text: 'Thank you all so much!',
        ),
      ];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      expect(find.text('A reply'), findsOneWidget);
      expect(find.text('Ananya'), findsOneWidget);
      expect(find.text('Thank you all so much!'), findsOneWidget);
    });

    testWidgets('your own reply says who it went to, not your name', (
      tester,
    ) async {
      repo.mine = [
        buildCapsule(
          id: 'm1',
          status: MemoryStatus.unlocked,
          isHost: false,
          isRecipient: true,
        ),
      ];
      repo.repliesOnCapsule = [
        buildReply(id: 'r1', isMine: true, recipientCount: 3),
      ];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      expect(find.text('You replied to 3 people'), findsOneWidget);
    });

    testWidgets('with none, the section is absent rather than empty', (
      tester,
    ) async {
      repo.mine = [buildCapsule(id: 'm1', status: MemoryStatus.unlocked)];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      // A heading over blank space asks the reader to wonder what is missing.
      expect(find.textContaining('repl'), findsNothing);
    });
  });

  group('choosing who to send it to', () {
    testWidgets('one row per person, however many memories they sent', (
      tester,
    ) async {
      repo.audience = [
        buildAudienceEntry(userId: 'u_host', displayName: 'Jayanth'),
        buildAudienceEntry(
          userId: 'u_host',
          displayName: 'Jayanth',
          capsuleId: 'm2',
          capsuleTitle: 'Diwali',
        ),
        buildAudienceEntry(
          userId: 'u_priya',
          displayName: 'Priya',
          isHost: false,
        ),
      ];
      final container = await pump(
        tester,
        const ReplyRecipientsScreen(memoryId: 'm1'),
      );
      container.read(replyProvider.notifier).setText('Thank you');
      container.read(replyProvider.notifier).setKind(MemoryWishKind.text);
      await tester.pumpAndSettle();

      expect(find.text('Jayanth'), findsOneWidget);
      expect(find.text('Priya'), findsOneWidget);
      // Two memories from the same person collapse into one row that says so.
      expect(find.text('2 memories'), findsOneWidget);
      expect(find.text('Wrote in Ananya\'s Birthday'), findsOneWidget);
    });

    testWidgets('the memory it was started from begins ticked', (tester) async {
      repo.audience = [
        buildAudienceEntry(userId: 'u_host', capsuleId: 'm1'),
        buildAudienceEntry(
          userId: 'u_other',
          displayName: 'Rahul',
          capsuleId: 'm2',
        ),
      ];
      final container = await pump(
        tester,
        const ReplyRecipientsScreen(memoryId: 'm1'),
      );
      await tester.pumpAndSettle();

      // Preselected, but not exclusively: the other memory's sender is still
      // on the list to be added.
      expect(container.read(replyProvider).recipientIds, {'u_host'});
      expect(find.text('Rahul'), findsOneWidget);
    });

    testWidgets('the button counts who it will reach', (tester) async {
      repo.audience = [
        buildAudienceEntry(userId: 'u_host', capsuleId: 'm1'),
        buildAudienceEntry(
          userId: 'u_priya',
          displayName: 'Priya',
          capsuleId: 'm1',
        ),
      ];
      await pump(tester, const ReplyRecipientsScreen(memoryId: 'm1'));
      await tester.pumpAndSettle();

      expect(find.text('Send to 2 people'), findsOneWidget);
    });
  });

  group('the draft', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [memoriesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
    });

    ReplyController notifier() => container.read(replyProvider.notifier);
    ReplyState state() => container.read(replyProvider);

    test('a text reply needs words; a photo reply needs a file', () {
      notifier().setKind(MemoryWishKind.text);
      expect(state().composed, isFalse);
      notifier().setText('Thank you');
      expect(state().composed, isTrue);

      notifier().setKind(MemoryWishKind.photo);
      // Switching kind drops the file, and a photo reply has none yet.
      expect(state().composed, isFalse);
    });

    test('composed is not enough — it has to be addressed too', () {
      notifier()
        ..setKind(MemoryWishKind.text)
        ..setText('Thank you');
      expect(state().composed, isTrue);
      expect(state().canSend, isFalse, reason: 'nobody is selected yet');

      notifier().toggleRecipient('u_host');
      expect(state().canSend, isTrue);
    });

    test('toggling a recipient twice takes them off again', () {
      notifier()
        ..toggleRecipient('u_a')
        ..toggleRecipient('u_b')
        ..toggleRecipient('u_a');
      expect(state().recipientIds, {'u_b'});
    });

    test(
      'submitting sends the kind, the trimmed text and everyone chosen',
      () async {
        notifier()
          ..setKind(MemoryWishKind.text)
          ..setText('  Thank you all  ')
          ..toggleRecipient('u_host')
          ..toggleRecipient('u_priya');

        final reply = await notifier().submit();

        expect(reply, isNotNull);
        final call = repo.sendReplyCalls.single;
        expect(call['kind'], MemoryWishKind.text);
        expect(call['text'], 'Thank you all');
        expect(call['recipientIds'], containsAll(['u_host', 'u_priya']));
      },
    );

    test('an unaddressed draft never reaches the server', () async {
      notifier()
        ..setKind(MemoryWishKind.text)
        ..setText('Thank you');

      expect(await notifier().submit(), isNull);
      expect(repo.sendReplyCalls, isEmpty);
    });

    test('reset clears the draft, so the next reply starts blank', () {
      notifier()
        ..setKind(MemoryWishKind.text)
        ..setText('Thank you')
        ..toggleRecipient('u_host');

      notifier().reset();

      expect(state().text, isEmpty);
      expect(state().recipientIds, isEmpty);
    });
  });
}
