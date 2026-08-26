import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/features/onboarding/domain/profile_draft.dart';
import 'package:wishtick_flutter/features/onboarding/presentation/profile_controller.dart';

/// The face you leave alone is the face you get.
///
/// Create Profile always draws an avatar, so somebody who never opens the
/// picker still sees one and reasonably believes it is theirs. The draft used
/// to hold null in that state, `saveProfile` omits a null `avatarKey`, and the
/// account was stored with no avatar at all — correct-looking on the way in,
/// a bare initial to everybody else afterwards. Every account made through
/// real registration had landed that way.
void main() {
  ProfileFormController controllerOf(ProviderContainer c) =>
      c.read(profileFormProvider.notifier);
  ProfileFormState stateOf(ProviderContainer c) => c.read(profileFormProvider);

  ProviderContainer build() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh form already holds the default avatar', () {
    final c = build();

    // Not null. This is the whole fix: the preview and the draft agree from
    // the first frame, so submitting without touching anything saves a face.
    expect(stateOf(c).draft.avatar, BundledAvatar.defaultChoice);
    expect(stateOf(c).draft.avatar?.key, 'avatar_01');
  });

  test('picking a different avatar replaces the default', () {
    final c = build();

    controllerOf(c).setAvatar(const BundledAvatar(7));

    expect(stateOf(c).draft.avatar, const BundledAvatar(7));
  });

  /// The gallery path has to be able to get *back* to no-avatar, or the
  /// default would override the photo the person actually uploaded — the
  /// backend applies `avatarKey` after `photoMediaId` and clears the photo.
  test(
    'uploading from the gallery clears the default rather than losing to it',
    () {
      final c = build();

      controllerOf(c).setPhoto('media_1', localPath: '/tmp/pic.jpg');

      expect(stateOf(c).draft.avatar, isNull);
      expect(stateOf(c).draft.photoMediaId, 'media_1');
    },
  );

  test('the default survives filling in the rest of the form', () {
    final c = build();

    controllerOf(c)
      ..setName('Test1')
      ..setEmail('test1@example.com')
      ..setGender(Gender.male);

    // Every other setter goes through the same copyWith, so a stray
    // `clearAvatar` anywhere in the form would silently undo the default.
    expect(stateOf(c).draft.avatar, BundledAvatar.defaultChoice);
  });
}
