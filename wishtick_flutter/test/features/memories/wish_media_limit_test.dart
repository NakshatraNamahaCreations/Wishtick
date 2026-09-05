import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/media/media_limits.dart';
import 'package:wishtick_flutter/core/media/media_probe.dart';
import 'package:wishtick_flutter/core/media/media_repository.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/features/memories/data/memories_repository.dart';
import 'package:wishtick_flutter/features/memories/domain/memory.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_controller.dart';
import 'package:wishtick_flutter/features/memories/presentation/create_memory_wish_screen.dart';

import '../../helpers/memory_fakes.dart';

/// The size cap, said before the file is chosen and enforced at the picker.
///
/// The bug this closes: media is deliberately not uploaded until the host sets
/// an unlock moment, so an oversized clip was accepted at the composer, carried
/// through the preview, and only refused two screens later — with the message
/// landing on a date picker, which is nowhere near the choice that caused it.
void main() {
  const oneMb = 1024 * 1024;

  /// A picker that answers with one file of a given size, so the size check can
  /// be exercised without a real platform channel.
  ///
  /// `extends`, not `implements`: `FilePicker` is a `PlatformInterface` whose
  /// constructor passes the token its setter verifies, and it hands down
  /// default implementations for every method this does not care about.
  late _FakeFilePicker picker;

  setUp(() {
    picker = _FakeFilePicker();
    FilePicker.platform = picker;
  });

  /// Bounded pumps, for once a clip has been accepted.
  ///
  /// `video_player` has no plugin behind it in a test, so the preview that
  /// appears sits on a spinner that never resolves — and `pumpAndSettle` waits
  /// on it forever.
  Future<void> pumpBounded(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    MemoryWishKind kind = MemoryWishKind.video,
    int maxBytes = 10 * oneMb,
    int? maxDurationSeconds = 20,
    Duration? clipLength = const Duration(seconds: 8),
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        memoriesRepositoryProvider.overrideWithValue(FakeMemoriesRepository()),
        mediaLimitsProvider.overrideWith(
          (ref) async => MediaLimits({
            'memory_wish': PurposeLimit(
              maxBytes: maxBytes,
              maxDurationSeconds: maxDurationSeconds,
              mimeTypes: const [],
            ),
          }),
        ),
        // The real probe opens a platform decoder, which a widget test has none
        // of.
        mediaDurationProbeProvider.overrideWithValue((_) async => clipLength),
      ],
    );
    addTearDown(container.dispose);
    container.read(createMemoryProvider.notifier).setWishKind(kind);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CreateMemoryWishScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('the caps are on screen before anything is picked', () {
    testWidgets('a video composer names the formats, length and size', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('MP4 or MOV · up to 20s · 10 MB'), findsOneWidget);
    });

    testWidgets('a voice note names its own formats', (tester) async {
      await pump(tester, kind: MemoryWishKind.audio);

      expect(
        find.text('MP3, M4A, AAC or WAV · up to 20s · 10 MB'),
        findsOneWidget,
      );
    });

    testWidgets('a photo is not given a running time', (tester) async {
      await pump(tester, kind: MemoryWishKind.photo);

      // A still has no length, and "up to 20s" over a photo picker is nonsense.
      expect(find.text('JPG, PNG, WEBP or HEIC · up to 10 MB'), findsOneWidget);
    });

    testWidgets('the numbers come from the server, not constants', (
      tester,
    ) async {
      // A deployment that raises MEDIA_MAX_BYTES or relaxes the duration must
      // not leave the app quoting the old figures. This is why both are fetched
      // rather than hardcoded.
      await pump(tester, maxBytes: 25 * oneMb, maxDurationSeconds: 45);

      expect(find.text('MP4 or MOV · up to 45s · 25 MB'), findsOneWidget);
    });
  });

  group('a clip longer than the limit never leaves the composer', () {
    testWidgets('it is refused, with its real length in the message', (
      tester,
    ) async {
      final container = await pump(
        tester,
        clipLength: const Duration(seconds: 24),
      );
      picker.result = _pick('birthday.mp4', 2 * oneMb);

      await tester.tap(find.text('Add a video'));
      await tester.pumpAndSettle();

      expect(
        find.text('That video message runs 24s. Keep it under 20s.'),
        findsOneWidget,
      );
      expect(container.read(createMemoryProvider).wishFilePath, isNull);
    });

    testWidgets('a long one reads in minutes, not 312 seconds', (tester) async {
      await pump(tester, clipLength: const Duration(minutes: 5, seconds: 12));
      picker.result = _pick('film.mp4', 2 * oneMb);

      await tester.tap(find.text('Add a video'));
      await tester.pumpAndSettle();

      expect(
        find.text('That video message runs 5m 12s. Keep it under 20s.'),
        findsOneWidget,
      );
    });

    testWidgets('exactly on the limit is allowed', (tester) async {
      final container = await pump(
        tester,
        clipLength: const Duration(seconds: 20),
      );
      picker.result = _pick('exact.mp4', 2 * oneMb);

      await tester.tap(find.text('Add a video'));
      await pumpBounded(tester);

      expect(container.read(createMemoryProvider).wishFileName, 'exact.mp4');
    });

    testWidgets('a fraction over the limit is not', (tester) async {
      // The server rounds the same way. Letting 20.4s through would only hand
      // the user a failure further down the line.
      final container = await pump(
        tester,
        clipLength: const Duration(milliseconds: 20_400),
      );
      picker.result = _pick('nearly.mp4', 2 * oneMb);

      await tester.tap(find.text('Add a video'));
      await tester.pumpAndSettle();

      expect(container.read(createMemoryProvider).wishFilePath, isNull);
    });

    testWidgets('a clip the device cannot measure is allowed through', (
      tester,
    ) async {
      // A null probe means "unknown", never "zero". Refusing here would block
      // clips that are fine on a device whose decoder is merely fussy about the
      // container — and the server measures it again after the encode.
      final container = await pump(tester, clipLength: null);
      picker.result = _pick('odd-codec.mov', 2 * oneMb);

      await tester.tap(find.text('Add a video'));
      await pumpBounded(tester);

      expect(
        container.read(createMemoryProvider).wishFileName,
        'odd-codec.mov',
      );
    });

    testWidgets('no duration cap means no probe is enforced', (tester) async {
      final container = await pump(
        tester,
        maxDurationSeconds: null,
        clipLength: const Duration(minutes: 9),
      );
      picker.result = _pick('long.mp4', 2 * oneMb);

      await tester.tap(find.text('Add a video'));
      await pumpBounded(tester);

      expect(container.read(createMemoryProvider).wishFileName, 'long.mp4');
    });
  });

  group('an oversized file never leaves the composer', () {
    testWidgets('it is refused at the picker, with the size in the message', (
      tester,
    ) async {
      final container = await pump(tester);
      picker.result = _pick('birthday.mp4', 11 * oneMb);

      await tester.tap(find.text('Add a video'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'That video message is larger than 10 MB. Pick a smaller one.',
        ),
        findsOneWidget,
      );
      // Nothing was kept, so the draft cannot carry it forward.
      expect(container.read(createMemoryProvider).wishFilePath, isNull);
    });

    testWidgets('Preview Memory stays disabled after a refusal', (
      tester,
    ) async {
      await pump(tester);
      picker.result = _pick('birthday.mp4', 11 * oneMb);

      await tester.tap(find.text('Add a video'));
      await tester.pumpAndSettle();

      // The whole point of refusing early: the oversized clip cannot reach the
      // preview screen, let alone the unlock screen that used to report it.
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Preview Memory'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a file inside the limit is kept, and clears the error', (
      tester,
    ) async {
      final container = await pump(tester);

      picker.result = _pick('huge.mp4', 11 * oneMb);
      await tester.tap(find.text('Add a video'));
      await tester.pumpAndSettle();
      expect(find.textContaining('larger than'), findsOneWidget);

      picker.result = _pick('small.mp4', 2 * oneMb);
      await tester.tap(find.text('Add a video'));
      await pumpBounded(tester);

      expect(container.read(createMemoryProvider).wishFileName, 'small.mp4');
      expect(
        find.textContaining('larger than'),
        findsNothing,
        reason: 'the complaint about the last file must not outlive it',
      );
    });

    testWidgets('a file exactly on the limit is allowed', (tester) async {
      final container = await pump(tester);
      picker.result = _pick('exact.mp4', 10 * oneMb);

      await tester.tap(find.text('Add a video'));
      await pumpBounded(tester);

      // The server's own check is `>`, so the boundary is inclusive on both
      // sides. An app that refused here would reject a file the API accepts.
      expect(container.read(createMemoryProvider).wishFileName, 'exact.mp4');
    });
  });

  group('MediaLimits', () {
    test('a purpose the server did not name falls back, conservatively', () {
      const limits = MediaLimits.fallback;

      // Too low only asks for a smaller file; too high promises an upload that
      // will fail. Against an older API, guess low.
      expect(limits.forPurpose(MediaPurpose.memoryWish).maxBytes, 10 * oneMb);
    });

    test('it reads the wire format', () {
      final limits = MediaLimits.fromJson({
        'memory_wish': {
          'maxBytes': 50 * oneMb,
          'maxDurationSeconds': 20,
          'mimeTypes': ['video/mp4'],
        },
      });

      final wish = limits.forPurpose(MediaPurpose.memoryWish);
      expect(wish.maxBytes, 50 * oneMb);
      expect(wish.mimeTypes, ['video/mp4']);
      expect(wish.label, '50 MB');
      expect(wish.durationLabel, '20s');
    });

    test('a null duration on the wire means uncapped, not zero', () {
      final limits = MediaLimits.fromJson({
        'wishlist_cover': {'maxBytes': 8 * oneMb, 'maxDurationSeconds': null},
      });

      final cover = limits.forPurpose(MediaPurpose.wishlistCover);
      expect(cover.maxDurationSeconds, isNull);
      expect(cover.durationLabel, isNull);
      expect(cover.acceptsDuration(const Duration(hours: 1)), isTrue);
    });

    test('the fallback invents no duration ceiling', () {
      // Guessing one would refuse clips the server would have taken — the
      // opposite of the size fallback, where guessing low is the safe side.
      const limits = MediaLimits.fallback;
      final wish = limits.forPurpose(MediaPurpose.memoryWish);

      expect(wish.maxDurationSeconds, isNull);
      expect(wish.acceptsDuration(const Duration(minutes: 5)), isTrue);
    });

    test('the label floors rather than rounds', () {
      // Rounding up would print a number the server refuses.
      const limit = PurposeLimit(maxBytes: 10 * oneMb + 900_000, mimeTypes: []);
      expect(limit.label, '10 MB');
    });
  });
}

FilePickerResult _pick(String name, int size) => FilePickerResult([
  PlatformFile(name: name, size: size, path: '/tmp/$name'),
]);

class _FakeFilePicker extends FilePicker {
  FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated('allowCompression is deprecated and has no effect.')
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}
