import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/media/media_repository.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/memories/data/memories_repository.dart';
import 'package:wishtick_flutter/features/memories/domain/memory.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_controller.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_wish_preview_screen.dart';

import '../../helpers/memory_fakes.dart';
import '../../helpers/wishlist_fakes.dart';
import '../../helpers/wishmates_fakes.dart';

/// The host's own first wish, composed while the memory is still a draft.
void main() {
  late FakeMemoriesRepository repo;
  late FakeMediaRepository media;
  late ProviderContainer container;

  CreateMemoryController notifier() =>
      container.read(createMemoryProvider.notifier);
  CreateMemoryState state() => container.read(createMemoryProvider);

  setUp(() {
    repo = FakeMemoriesRepository();
    media = FakeMediaRepository();
    container = ProviderContainer(
      overrides: [
        memoriesRepositoryProvider.overrideWithValue(repo),
        mediaRepositoryProvider.overrideWithValue(media),
      ],
    );
    addTearDown(container.dispose);
  });

  void fillStep1() {
    notifier()
      ..setTitle('Happy Birthday')
      ..setRecipient(buildWishmate(displayName: 'Ananya'))
      ..setRelation('best_friend', 'Best Friend');
  }

  group('wishReady', () {
    test('a text wish needs words', () {
      notifier().setWishKind(MemoryWishKind.text);
      expect(state().wishReady, isFalse);

      notifier().setWishText('Happy birthday!');
      expect(state().wishReady, isTrue);
    });

    /// The label says "(Optional)", so the rule has to match the label.
    test('a photo wish needs a file, and its message stays optional', () {
      notifier().setWishKind(MemoryWishKind.photo);
      expect(state().wishReady, isFalse);

      notifier().setWishFile(path: '/tmp/a.jpg', name: 'a.jpg');
      expect(state().wishReady, isTrue);
      expect(state().wishText, isEmpty);
    });

    /// A file left behind on a wish that is now a different kind would be
    /// uploaded, paid for, and never shown.
    test('changing the kind drops the file picked for the previous one', () {
      notifier()
        ..setWishKind(MemoryWishKind.photo)
        ..setWishFile(path: '/tmp/a.jpg', name: 'a.jpg');

      notifier().setWishKind(MemoryWishKind.video);

      expect(state().wishFilePath, isNull);
      expect(state().wishFileName, isNull);
      expect(state().wishReady, isFalse);
    });
  });

  group('submit', () {
    test('posts the composed wish once the capsule exists', () async {
      fillStep1();
      notifier()
        ..setWishKind(MemoryWishKind.photo)
        ..setWishFile(path: '/tmp/a.jpg', name: 'a.jpg')
        ..setWishText('  Happy Birthday!  ')
        ..setUnlockDate(DateTime(2027, 7, 19));

      final capsule = await notifier().submit();

      expect(capsule, isNotNull);
      // Nothing was uploaded while composing; the bytes go up here, once.
      expect(media.uploadCalls, [MediaPurpose.memoryWish]);
      expect(repo.addWishCalls, hasLength(1));
      final sent = repo.addWishCalls.single;
      expect(sent['kind'], MemoryWishKind.photo);
      expect(sent['mediaId'], isNotNull);
      expect(sent['text'], 'Happy Birthday!', reason: 'trimmed before sending');
    });

    test('creates the memory even when no wish was composed', () async {
      fillStep1();
      notifier().setUnlockDate(DateTime(2027, 7, 19));

      final capsule = await notifier().submit();

      expect(capsule, isNotNull);
      expect(repo.addWishCalls, isEmpty);
      expect(media.uploadCalls, isEmpty);
    });
  });

  group('Preview', () {
    testWidgets('shows the photo, the message and who it is for', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(393, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      fillStep1();
      notifier()
        ..setWishKind(MemoryWishKind.photo)
        ..setWishFile(path: '/tmp/a.jpg', name: 'a.jpg')
        ..setWishText('Happy Birthday!');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const CreateMemoryWishPreviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Happy Birthday!'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.text('Ananya'), findsOneWidget);
      expect(find.text('Best Friend'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
    });
  });
}
