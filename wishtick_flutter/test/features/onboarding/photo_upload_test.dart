import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/onboarding/domain/profile_draft.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/profile_controller.dart';

/// Onboarding's camera badge sat on a "photo upload arrives in Sprint 9"
/// snackbar until *after* Sprint 9 shipped the upload on Edit Profile — the
/// screen that comment pointed at. These pin the draft plumbing behind it.
void main() {
  ProfileFormController controllerOf(ProviderContainer c) =>
      c.read(profileFormProvider.notifier);
  ProfileFormState stateOf(ProviderContainer c) => c.read(profileFormProvider);

  ProviderContainer build() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('an uploaded photo reaches the draft with a preview path', () {
    final c = build();

    controllerOf(c).setPhoto('media_1', localPath: '/tmp/pic.jpg');

    expect(stateOf(c).draft.photoMediaId, 'media_1');
    expect(stateOf(c).photoLocalPath, '/tmp/pic.jpg');
  });

  /// The backend stores one or the other, so the form must not hold both —
  /// otherwise whichever the server prefers decides, not the user.
  test('a photo and a bundled avatar are mutually exclusive', () {
    final c = build();

    controllerOf(c).setPhoto('media_1', localPath: '/tmp/pic.jpg');
    controllerOf(c).setAvatar(const BundledAvatar(3));

    expect(stateOf(c).draft.photoMediaId, isNull);
    expect(stateOf(c).photoLocalPath, isNull, reason: 'preview must clear too');
    expect(stateOf(c).draft.avatar, const BundledAvatar(3));

    controllerOf(c).setPhoto('media_2', localPath: '/tmp/other.jpg');
    expect(stateOf(c).draft.avatar, isNull);
    expect(stateOf(c).draft.photoMediaId, 'media_2');
  });

  test('a failed upload clears the spinner and reports why', () {
    final c = build();

    controllerOf(c).setUploadingPhoto(true);
    expect(stateOf(c).uploadingPhoto, isTrue);

    controllerOf(c).failPhoto('Could not upload that photo.');

    expect(stateOf(c).uploadingPhoto, isFalse);
    expect(stateOf(c).error, 'Could not upload that photo.');
  });
}
