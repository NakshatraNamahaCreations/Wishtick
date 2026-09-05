import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/memories/data/memories_repository.dart';
import 'package:wishtick_flutter/features/memories/domain/memory.dart';
import 'package:wishtick_flutter/features/memories/presentation/add_wish_controller.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_controller.dart';
import 'package:wishtick_flutter/features/memories/presentation/memories_tab_screen.dart';
import 'package:wishtick_flutter/features/memories/presentation/memory_detail_screen.dart';
import 'package:wishtick_flutter/features/memories/presentation/memory_experience_screen.dart';
import 'package:wishtick_flutter/features/memories/presentation/my_wishes_screen.dart';
import 'package:wishtick_flutter/features/memories/presentation/widgets/memory_players.dart';

import '../../helpers/memory_fakes.dart';
import '../../helpers/wishmates_fakes.dart';

void main() {
  late FakeMemoriesRepository repo;

  setUp(() {
    repo = FakeMemoriesRepository();
  });

  /// Bounded pumps, for a screen holding a media player.
  ///
  /// `video_player` has no plugin behind it in a test, so `initialize()` never
  /// resolves and the player sits on a spinner — which `pumpAndSettle` waits on
  /// forever.
  Future<void> pumpBounded(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoriesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: theme ?? AppTheme.light, home: child),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
  }) async {
    // A phone, not the 800×600 default: the carousels and the bottom actions
    // sit below the fold at that size.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [memoriesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(theme: theme ?? AppTheme.light, home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Memories tab (4104:1433)', () {
    testWidgets('shows the hero and every band', (tester) async {
      repo.mine = [buildCapsule(id: 'm1', title: "Ananya's Birthday")];
      repo.contributed = [
        buildCapsule(id: 'm2', title: "Rahul's House warming", isHost: false),
      ];
      await pump(tester, const MemoriesTabScreen());

      expect(find.text('Every wish locked with Love'), findsOneWidget);
      expect(find.text('Upcoming Unlocks'), findsOneWidget);
      expect(find.text('For You'), findsOneWidget);
      expect(find.text('Created By You'), findsOneWidget);
      expect(find.text("Ananya's Birthday"), findsWidgets);

      // Below the fold now that "For You" sits above it.
      await tester.scrollUntilVisible(
        find.text('Contributed By You'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Contributed By You'), findsOneWidget);
    });

    testWidgets('a memory made for you lands in For You, above your own', (
      tester,
    ) async {
      repo.forMe = [
        buildCapsule(
          id: 'm9',
          title: 'A memory for you',
          status: MemoryStatus.unlocked,
          isHost: false,
        ),
      ];
      await pump(tester, const MemoriesTabScreen());

      expect(find.text('For You'), findsOneWidget);
      expect(find.text('A memory for you'), findsWidgets);
      // First, because it is the one thing on this tab the viewer has not
      // already seen — the others are their own work.
      expect(
        tester.getTopLeft(find.text('For You')).dy,
        lessThan(tester.getTopLeft(find.text('Created By You')).dy),
      );
    });

    testWidgets('an opened capsule appears in the Unlocked row', (
      tester,
    ) async {
      repo.mine = [
        buildCapsule(id: 'm1', status: MemoryStatus.unlocked, wishCount: 3),
        buildCapsule(id: 'm2', title: 'Still sealed'),
      ];
      await pump(tester, const MemoriesTabScreen());

      expect(find.text('Unlocked Memories'), findsOneWidget);
      // Sealed ones stay in Upcoming, not in the circles.
      expect(find.text('Still sealed'), findsWidgets);
    });

    testWidgets('with nothing yet, each band says what would fill it', (
      tester,
    ) async {
      await pump(tester, const MemoriesTabScreen());

      expect(find.text('Nothing sealed just yet.'), findsOneWidget);
      expect(
        find.text('Create a memory and invite people to fill it.'),
        findsOneWidget,
      );
      // No circles at all when nothing has opened.
      expect(find.text('Unlocked Memories'), findsNothing);
    });
  });

  group('Capsule detail', () {
    testWidgets('a sealed capsule promises nothing about its contents', (
      tester,
    ) async {
      repo.mine = [
        buildCapsule(
          id: 'm1',
          wishCount: 4,
          contributors: const ['Priya', 'Rahul'],
        ),
      ];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      expect(find.text('4 Wishes'), findsOneWidget);
      expect(find.text('From Priya, Rahul'), findsOneWidget);
      expect(
        find.textContaining('not even you'),
        findsOneWidget,
        reason: 'the sealed panel must say the host cannot read it either',
      );
      expect(find.text('Add a Wish'), findsOneWidget);
    });

    testWidgets('nothing on a sealed capsule can force it open', (
      tester,
    ) async {
      repo.mine = [buildCapsule(id: 'm1', wishCount: 2)];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      // "Open it now" is gone for good: it revealed everyone's wishes at once,
      // irreversibly, to answer a question the preview answers for free.
      expect(find.text('Open it now'), findsNothing);
      // And with nothing of the host's own inside, there is nothing to preview.
      expect(find.textContaining('Preview my'), findsNothing);
    });

    testWidgets('having written one, the host is asked for another', (
      tester,
    ) async {
      repo.mine = [buildCapsule(id: 'm1', wishCount: 3, myWishCount: 1)];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      expect(find.text('Add Another Wish'), findsOneWidget);
      expect(find.text('Add a Wish'), findsNothing);
      // Singular while there is one; the count is the host's own, not the four
      // wishes in the capsule.
      expect(find.text('Preview my wish'), findsOneWidget);
    });

    testWidgets('the preview counts only the host\'s own wishes', (
      tester,
    ) async {
      repo.mine = [buildCapsule(id: 'm1', wishCount: 9, myWishCount: 2)];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      expect(find.text('Preview my 2 wishes'), findsOneWidget);
    });

    testWidgets('an opened capsule offers the story instead', (tester) async {
      repo.mine = [
        buildCapsule(
          id: 'm1',
          status: MemoryStatus.unlocked,
          wishCount: 2,
          myWishCount: 1,
        ),
      ];
      await pump(tester, const MemoryDetailScreen(memoryId: 'm1'));

      expect(find.text('Open the Memory'), findsOneWidget);
      expect(find.text('Add a Wish'), findsNothing);
      expect(find.text('Open it now'), findsNothing);
      // Once it is open the whole story is readable, so a private preview of
      // one's own corner of it is just a second door to the same room.
      expect(find.textContaining('Preview my'), findsNothing);
    });
  });

  group('Previewing your own wishes', () {
    testWidgets('a sealed capsule still shows you what you wrote', (
      tester,
    ) async {
      repo.mine = [buildCapsule(id: 'm1', wishCount: 5, myWishCount: 2)];
      repo.ownWishes = [
        buildWish(id: 'w1', contributorName: 'You', text: 'Many happy years'),
        buildWish(id: 'w2', contributorName: 'You', text: 'See you Sunday'),
      ];
      await pump(tester, const MyWishesScreen(memoryId: 'm1'));

      expect(find.text('Many happy years'), findsOneWidget);
      expect(find.text('See you Sunday'), findsOneWidget);
    });

    testWidgets('it asks the server for your wishes, not the capsule\'s', (
      tester,
    ) async {
      // The capsule's own `wishes` list is empty while sealed — that is the
      // time-lock doing its job. Reading it instead would show nothing.
      repo.mine = [buildCapsule(id: 'm1', wishCount: 5, myWishCount: 1)];
      repo.ownWishes = [
        buildWish(id: 'w1', contributorName: 'You', text: 'Mine alone'),
      ];
      await pump(tester, const MyWishesScreen(memoryId: 'm1'));

      expect(find.text('Mine alone'), findsOneWidget);
    });

    testWidgets('with none of your own, it says so plainly', (tester) async {
      repo.mine = [buildCapsule(id: 'm1', wishCount: 5)];
      await pump(tester, const MyWishesScreen(memoryId: 'm1'));

      expect(
        find.textContaining('not added a wish'),
        findsOneWidget,
        reason: 'an empty list must not read as a loading failure',
      );
    });
  });

  group('The experience (2078:357)', () {
    testWidgets('walks the wishes one segment at a time', (tester) async {
      repo.mine = [
        buildCapsule(
          id: 'm1',
          status: MemoryStatus.unlocked,
          wishCount: 2,
          wishes: [
            buildWish(id: 'w1', contributorName: 'Priya', text: 'First wish'),
            buildWish(id: 'w2', contributorName: 'Ganesh', text: 'Second wish'),
          ],
        ),
      ];
      await pump(tester, const MemoryExperienceScreen(memoryId: 'm1'));

      expect(find.text('2 Wishes'), findsOneWidget);
      expect(find.text('Priya'), findsOneWidget);
      // Exactly once: a text wish's card IS its message, so repeating it
      // beneath the card reads as the same message sent twice.
      expect(find.text('First wish'), findsOneWidget);

      // Tapping the right side advances.
      await tester.tapAt(const Offset(350, 500));
      await tester.pumpAndSettle();
      expect(find.text('Ganesh'), findsOneWidget);
      expect(find.text('Second wish'), findsOneWidget);
    });

    testWidgets('a sealed capsule shows the countdown, not an error', (
      tester,
    ) async {
      repo.mine = [buildCapsule(id: 'm1', wishCount: 3)];
      await pump(tester, const MemoryExperienceScreen(memoryId: 'm1'));

      expect(find.textContaining('Unlocks in'), findsOneWidget);
      expect(
        find.text('Nothing inside can be read until then.'),
        findsOneWidget,
      );
    });

    testWidgets('reacting calls through', (tester) async {
      repo.mine = [
        buildCapsule(
          id: 'm1',
          status: MemoryStatus.unlocked,
          wishCount: 1,
          wishes: [buildWish(id: 'w1', contributorName: 'Priya')],
        ),
      ];
      await pump(tester, const MemoryExperienceScreen(memoryId: 'm1'));

      await tester.tap(find.text('React'));
      await tester.pumpAndSettle();
      expect(repo.reactCalls, ['w1']);
    });

    testWidgets('a voice note and a video get real players, not glyphs', (
      tester,
    ) async {
      repo.mine = [
        buildCapsule(
          id: 'm1',
          status: MemoryStatus.unlocked,
          wishCount: 2,
          wishes: [
            buildWish(
              id: 'w1',
              contributorName: 'Rahul',
              kind: MemoryWishKind.audio,
              text: null,
              mediaUrl: 'https://cdn.test/note.m4a',
              durationMs: 20_000,
            ),
          ],
        ),
      ];
      await pumpBounded(tester, const MemoryExperienceScreen(memoryId: 'm1'));

      // The player itself, not the ornamental waveform that stands in when a
      // wish has no file behind it.
      expect(find.byType(MemoryAudioPlayer), findsOneWidget);
    });

    testWidgets('a video wish gets a video player', (tester) async {
      repo.mine = [
        buildCapsule(
          id: 'm1',
          status: MemoryStatus.unlocked,
          wishCount: 1,
          wishes: [
            buildWish(
              id: 'w1',
              contributorName: 'Priya',
              kind: MemoryWishKind.video,
              text: null,
              mediaUrl: 'https://cdn.test/clip.mp4',
              durationMs: 20_000,
            ),
          ],
        ),
      ];
      await pumpBounded(tester, const MemoryExperienceScreen(memoryId: 'm1'));

      expect(find.byType(MemoryVideoPlayer), findsOneWidget);
    });

    testWidgets('is dark even when the app is light', (tester) async {
      // A lights-down moment: the frames are dark, so the viewer's own theme
      // must not turn the story beige.
      repo.mine = [
        buildCapsule(
          id: 'm1',
          status: MemoryStatus.unlocked,
          wishCount: 1,
          wishes: [buildWish(id: 'w1', contributorName: 'Priya')],
        ),
      ];
      await pump(tester, const MemoryExperienceScreen(memoryId: 'm1'));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        ThemeData.estimateBrightnessForColor(scaffold.backgroundColor!),
        Brightness.dark,
      );
    });
  });

  group('Create-memory controller', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [memoriesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
    });

    CreateMemoryController notifier() =>
        container.read(createMemoryProvider.notifier);
    CreateMemoryState state() => container.read(createMemoryProvider);

    void fillStep1() {
      notifier()
        ..setTitle("Ananya's Birthday")
        ..setRecipient(buildIdentity(userId: 'u_ananya', displayName: 'Ananya'))
        ..setRelation('partner_wife', 'Wife');
    }

    test('step 1 is not complete until a WishMate is chosen', () {
      notifier()
        ..setTitle("Ananya's Birthday")
        ..setRelation('partner_wife', 'Wife');

      // A memory is made *for* an account, and the server refuses a recipient
      // the host is not linked to — so there is nothing to submit yet.
      expect(state().recipient, isNull);
      expect(state().step1Complete, isFalse);

      notifier().setRecipient(
        buildIdentity(userId: 'u_ananya', displayName: 'Ananya'),
      );
      expect(state().step1Complete, isTrue);
    });

    test('submitting sends the recipient id, not a typed name', () async {
      fillStep1();
      notifier()
        ..setUnlockDate(DateTime.now().add(const Duration(days: 3)))
        ..setUnlockTime(const MemoryTimeOfDay(18, 30));

      await notifier().submit();

      expect(repo.createCalls.single['recipientUserId'], 'u_ananya');
      expect(repo.createCalls.single.containsKey('personName'), isFalse);
    });

    test('step 1 needs all three starred fields', () {
      expect(state().step1Complete, isFalse);
      notifier()
        ..setTitle("Ananya's Birthday")
        ..setRecipient(
          buildIdentity(userId: 'u_ananya', displayName: 'Ananya'),
        );
      // Relation is still missing.
      expect(state().step1Complete, isFalse);

      notifier().setRelation('partner_wife', 'Wife');
      expect(state().step1Complete, isTrue);
    });

    /// The time defaults to midnight, so a capsule is waiting the moment its
    /// day starts and the date alone finishes the step. It used to *show*
    /// 12:00 AM while holding null, which left Save & Continue disabled on a
    /// form that looked complete.
    test(
      'the unlock time starts at midnight, so a date alone completes it',
      () {
        fillStep1();
        expect(state().unlockTime, const MemoryTimeOfDay(0, 0));

        notifier().setUnlockDate(DateTime(2026, 7, 19));

        expect(state().step2Complete, isTrue);
        expect(state().unlockAt, DateTime(2026, 7, 19));
      },
    );

    test('picking a different time replaces the default', () {
      fillStep1();
      notifier()
        ..setUnlockDate(DateTime(2026, 7, 19))
        ..setUnlockTime(const MemoryTimeOfDay(18, 30));

      expect(state().unlockAt, DateTime(2026, 7, 19, 18, 30));
    });

    test(
      'submit sends an IANA timezone, not the platform abbreviation',
      () async {
        fillStep1();
        notifier()
          ..setUnlockDate(DateTime(2026, 7, 19))
          ..setUnlockTime(const MemoryTimeOfDay(20, 0));

        await notifier().submit();

        expect(repo.createCalls.single['timezone'], 'Asia/Kolkata');
      },
    );

    test('an incomplete draft never reaches the server', () async {
      fillStep1();
      // No unlock instant.
      expect(await notifier().submit(), isNull);
      expect(repo.createCalls, isEmpty);
    });

    test('the occasion date keeps the day and month without a year', () {
      notifier()
        ..setOccasionDay(17)
        ..setOccasionMonth(7);

      final value = state().occasionDateValue;
      expect(value.day, 17);
      expect(value.month, 7);
      // Without "Include Year" it lands on the current year rather than year 0.
      expect(value.year, DateTime.now().year);
    });
  });

  group('Add-wish controller', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [memoriesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
    });

    test('a text wish needs words; a photo wish needs a file', () {
      final notifier = container.read(addWishProvider('m1').notifier);

      notifier.setKind(MemoryWishKind.text);
      expect(container.read(addWishProvider('m1')).canPreview, isFalse);
      notifier.setText('Happy Birthday!');
      expect(container.read(addWishProvider('m1')).canPreview, isTrue);

      notifier.setKind(MemoryWishKind.photo);
      // Switching kind drops the file, and a message alone is not enough.
      expect(container.read(addWishProvider('m1')).canPreview, isFalse);
      notifier.setMedia(
        mediaId: 'med_1',
        mediaUrl: 'https://cdn.test/a.jpg',
        fileName: 'a.jpg',
      );
      expect(container.read(addWishProvider('m1')).canPreview, isTrue);
    });

    test('switching kind clears the file picked for the previous one', () {
      final notifier = container.read(addWishProvider('m1').notifier);
      notifier
        ..setKind(MemoryWishKind.photo)
        ..setMedia(
          mediaId: 'med_1',
          mediaUrl: 'https://cdn.test/a.jpg',
          fileName: 'a.jpg',
        );
      expect(container.read(addWishProvider('m1')).mediaId, 'med_1');

      notifier.setKind(MemoryWishKind.video);
      expect(container.read(addWishProvider('m1')).mediaId, isNull);
    });

    test('submitting sends the kind and the trimmed message', () async {
      final notifier = container.read(addWishProvider('m1').notifier);
      notifier
        ..setKind(MemoryWishKind.photo)
        ..setMedia(
          mediaId: 'med_1',
          mediaUrl: 'https://cdn.test/a.jpg',
          fileName: 'a.jpg',
        )
        ..setText('  Happy Birthday!  ');

      await notifier.submit();

      final call = repo.addWishCalls.single;
      expect(call['capsuleId'], 'm1');
      expect(call['kind'], MemoryWishKind.photo);
      expect(call['text'], 'Happy Birthday!');
      expect(call['mediaId'], 'med_1');
    });

    test('two capsules do not share a half-written wish', () {
      container.read(addWishProvider('m1').notifier).setText('For Mridula');
      expect(container.read(addWishProvider('m2')).text, isEmpty);
    });
  });
}
