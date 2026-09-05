import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/media/media_repository.dart';
import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/core/theme/app_theme.dart';
import 'package:wishtick_flutter/core/widgets/wishtick_image.dart';
import 'package:wishtick_flutter/features/addresses/data/addresses_repository.dart';
import 'package:wishtick_flutter/features/home/data/home_repository.dart';
import 'package:wishtick_flutter/features/onboarding/data/onboarding_repository.dart';
import 'package:wishtick_flutter/features/wishlist/data/wishlist_repository.dart';
import 'package:wishtick_flutter/features/wishlist/domain/wishlist.dart';
import 'package:wishtick_flutter/features/wishlist/presentation/create_wishlist_screen.dart';
import 'package:wishtick_flutter/features/wishmates/data/wishmates_repository.dart';

import '../../helpers/home_fakes.dart';
import '../../helpers/onboarding_fakes.dart';
import '../../helpers/wishlist_fakes.dart';
import '../../helpers/wishmates_fakes.dart';

/// When the cover leaves the device.
///
/// Not at pick time: a cover uploaded the moment it was cropped left a file on
/// the CDN behind every Create Wishlist that was started and abandoned, with
/// no wishlist pointing at it and nothing to clean it up. It goes up as part
/// of saving, or not at all.
void main() {
  // A real 1x1 PNG: the preview decodes what it is handed, and undecodable
  // bytes fail the test with an image exception rather than a useful one.
  final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
    'hQGAhKmMIQAAAABJRU5ErkJggg==',
  );
  final otherPixel = Uint8List.fromList(pixel);

  late FakeWishlistRepository wishlists;
  late FakeMediaRepository media;

  setUp(() {
    CreateWishlistScreen.chooseCover = (_) async => pixel;
  });
  tearDown(() {
    CreateWishlistScreen.chooseCover = (_) async => null;
  });

  Future<void> pump(WidgetTester tester, {Wishlist? editing}) async {
    tester.view
      ..physicalSize = const Size(393, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    wishlists = FakeWishlistRepository(
      // Growable: creating adds to it.
      wishlists: [?editing],
    );
    media = FakeMediaRepository();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          wishlistRepositoryProvider.overrideWithValue(wishlists),
          mediaRepositoryProvider.overrideWithValue(media),
          // Saving an edit refreshes the lists that show the wishlist, and
          // Home is one of them — so everything Home fetches has to be a fake
          // here too, or the save waits out a real request that never lands.
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          addressesRepositoryProvider.overrideWithValue(
            FakeAddressesRepository(),
          ),
          wishmatesRepositoryProvider.overrideWithValue(
            FakeWishmatesRepository(mates: const []),
          ),
          onboardingRepositoryProvider.overrideWithValue(
            FakeOnboardingRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: CreateWishlistScreen(editing: editing),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The occasion grid is full of Images too; only the cover is drawn from
  // memory.
  Finder coverPreview() =>
      find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage);

  /// The cover slot whichever form it is in: memory while the pick is still
  /// on the device, network once it has been uploaded.
  Finder coverSlot() => find.byWidgetPredicate(
    (w) => (w is Image && w.image is MemoryImage) || w is WishtickImage,
  );

  Future<void> addCover(WidgetTester tester) async {
    await tester.tap(find.text('+ Add Cover Image'));
    await tester.pumpAndSettle();
  }

  /// Everything the form needs bar the cover, which each test supplies itself.
  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).first, 'Ananya');
    await tester.enterText(find.byType(TextFormField).at(1), 'Birthday');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(2), 'A few things');
    await tester.tap(find.text('Public'));
    await tester.pumpAndSettle();
  }

  Future<void> save(
    WidgetTester tester, {
    String label = 'Save Wishlist',
  }) async {
    final button = find.widgetWithText(ElevatedButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('choosing a cover sends nothing anywhere', (tester) async {
    await pump(tester);

    await addCover(tester);

    // It is on screen — drawn from memory, not from a CDN that has never
    // heard of it.
    expect(coverPreview(), findsOneWidget);
    expect(find.text('+ Add Cover Image'), findsNothing);
    expect(media.uploadCalls, isEmpty);
  });

  testWidgets('saving uploads it, and saves the id it came back with', (
    tester,
  ) async {
    await pump(tester);
    await addCover(tester);
    await fillForm(tester);

    await save(tester);

    expect(media.uploadCalls, [MediaPurpose.wishlistCover]);
    expect(wishlists.createCalls, ['Ananya']);
    expect(wishlists.wishlists.single.coverUrl, 'media_1');
  });

  // Order matters as much as the count: a wishlist written first and given its
  // cover afterwards is a wishlist that exists coverless if the upload fails.
  testWidgets('an upload that fails writes no wishlist at all', (tester) async {
    await pump(tester);
    await addCover(tester);
    await fillForm(tester);
    media.failure = const ApiException(
      code: 'upload_failed',
      message: 'Could not upload the cover',
    );

    await save(tester);

    expect(wishlists.createCalls, isEmpty);
    expect(find.text('Could not upload the cover'), findsOneWidget);
    // Still on the form, with the picture still in hand to try again with.
    expect(
      find.widgetWithText(ElevatedButton, 'Save Wishlist'),
      findsOneWidget,
    );
    expect(coverPreview(), findsOneWidget);
  });

  // The upload succeeded; it was the write that failed. Sending the same
  // picture a second time would leave the first copy orphaned on the CDN.
  testWidgets('a retry after a failed save does not upload twice', (
    tester,
  ) async {
    await pump(tester);
    await addCover(tester);
    await fillForm(tester);
    wishlists.failure = const ApiException(
      code: 'server_error',
      message: 'Something went wrong',
    );
    await save(tester);
    expect(media.uploadCalls, hasLength(1));

    wishlists.failure = null;
    await save(tester);

    expect(media.uploadCalls, hasLength(1));
    expect(wishlists.wishlists.single.coverUrl, 'media_1');
  });

  testWidgets('changing your mind uploads only the cover you kept', (
    tester,
  ) async {
    await pump(tester);
    await addCover(tester);
    await fillForm(tester);
    CreateWishlistScreen.chooseCover = (_) async => otherPixel;
    await tester.tap(coverPreview());
    await tester.pumpAndSettle();

    // The second picture is the one on screen. Same bytes, different object,
    // so this is identity — it says *which* pick the preview is showing.
    final shown = tester.widget<Image>(coverPreview()).image as MemoryImage;
    expect(identical(shown.bytes, otherPixel), isTrue);

    await save(tester);

    expect(media.uploadCalls, hasLength(1));
  });

  // The first picture is already on the CDN; the save it was uploaded for is
  // what failed. Picking a different one and saving must send the new one —
  // holding on to the first id would save a cover nobody chose.
  testWidgets('a cover picked after a failed save replaces the uploaded one', (
    tester,
  ) async {
    await pump(tester);
    await addCover(tester);
    await fillForm(tester);
    wishlists.failure = const ApiException(
      code: 'server_error',
      message: 'Something went wrong',
    );
    await save(tester);
    wishlists.failure = null;

    // Uploaded, so the slot is showing the CDN copy now, not the crop.
    CreateWishlistScreen.chooseCover = (_) async => otherPixel;
    await tester.tap(coverSlot());
    await tester.pumpAndSettle();
    await save(tester);

    expect(media.uploadCalls, hasLength(2));
    expect(wishlists.wishlists.single.coverUrl, 'media_2');
  });

  // Editing a list whose cover is already up there: there is nothing new to
  // send, and re-sending it would duplicate the file for no reason.
  testWidgets('an untouched cover is not uploaded again on edit', (
    tester,
  ) async {
    await pump(
      tester,
      editing: buildWishlist(
        id: 'wl_1',
        title: 'Ananya',
        coverUrl: 'media_old',
        occasionLabel: 'Birthday',
      ),
    );

    await save(tester, label: 'Save Changes');

    expect(media.uploadCalls, isEmpty);
    expect(wishlists.updateCalls, ['wl_1']);
    expect(wishlists.wishlists.single.coverUrl, 'media_old');
  });
}
