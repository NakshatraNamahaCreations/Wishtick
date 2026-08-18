import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../onboarding/domain/profile_draft.dart';
import '../../onboarding/presentation/widgets/gender_selector.dart';
import '../../onboarding/presentation/widgets/labelled_field.dart';
import 'edit_profile_controller.dart';
import 'profile_providers.dart';
import 'widgets/profile_avatar.dart';

/// "Edit Profile" (`90:21`).
///
/// The same form as onboarding's Create Your Profile, minus the progress bar
/// and the terms line — and *with* the photo upload that screen defers here.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  TextEditingController? _name;
  TextEditingController? _email;

  @override
  void dispose() {
    _name?.dispose();
    _email?.dispose();
    super.dispose();
  }

  /// Builds the text controllers the first time the profile lands, so the
  /// fields open filled rather than empty-then-populated.
  void _hydrate(EditProfileState state) {
    _name ??= TextEditingController(text: state.name);
    _email ??= TextEditingController(text: state.email);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final current = ref.read(editProfileProvider).dateOfBirth;

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 25, now.month, now.day),
      // Nobody alive is older than this, and a birthday cannot be in the future.
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      ref.read(editProfileProvider.notifier).setDateOfBirth(picked);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (picked == null) return;

    final notifier = ref.read(editProfileProvider.notifier);
    notifier.setUploading(true);
    try {
      final media = await ref
          .read(mediaRepositoryProvider)
          .uploadFile(file: picked, purpose: MediaPurpose.profilePhoto);
      notifier.setPhoto(mediaId: media.id, localPath: picked.path);
    } catch (_) {
      notifier.fail('Could not upload that photo.');
    } finally {
      notifier.setUploading(false);
    }
  }

  Future<void> _save() async {
    final saved = await ref.read(editProfileProvider.notifier).save();
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final me = ref.watch(meProvider);
    final state = ref.watch(editProfileProvider);
    final notifier = ref.read(editProfileProvider.notifier);
    _hydrate(state);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Edit Profile'),
      body: me.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.xl,
                AppSpacing.screenGutter,
                AppSpacing.xxl,
              ),
              children: [
                Center(
                  child: _PhotoCircle(
                    localPath: state.photoLocalPath,
                    photoUrl: me.value?.photoUrl,
                    avatarKey: state.avatarKey,
                    busy: state.uploadingPhoto,
                    onTap: state.uploadingPhoto
                        ? null
                        : () => unawaited(_pickPhoto()),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const _OrDivider(),
                const SizedBox(height: AppSpacing.xxl),
                _SelectAvatarCard(
                  avatarKey: state.avatarKey,
                  onTap: () => unawaited(_openAvatarPicker()),
                ),

                const SizedBox(height: AppSpacing.section),
                LabelledField(
                  label: 'Your Name',
                  required: true,
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    onChanged: notifier.setName,
                    decoration: const InputDecoration(
                      hintText: 'Enter your full name',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        size: AppSizes.iconMd,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                LabelledField(
                  label: 'Email ID',
                  required: true,
                  child: TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onChanged: notifier.setEmail,
                    decoration: const InputDecoration(
                      hintText: 'Enter your Email ID',
                      prefixIcon: Icon(
                        Icons.mail_outline,
                        size: AppSizes.iconMd,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                LabelledField(
                  label: 'Date of Birth',
                  required: true,
                  child: _DateField(
                    value: state.dateOfBirthDisplay,
                    onTap: () => unawaited(_pickDateOfBirth()),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                LabelledField(
                  label: 'Gender',
                  required: true,
                  child: GenderSelector(
                    value: state.gender,
                    onChanged: notifier.setGender,
                  ),
                ),

                if (state.error != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  WishtickErrorText(state.error!),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.busy ? null : () => unawaited(_save()),
              child: const Text('Save & Next'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAvatarPicker() async {
    final key = await context.push<String>(AppRoutes.onboardingAvatar);
    if (key != null) ref.read(editProfileProvider.notifier).setAvatar(key);
  }
}

/// The face with a plum camera badge on its lower-right.
class _PhotoCircle extends StatelessWidget {
  const _PhotoCircle({
    required this.localPath,
    required this.photoUrl,
    required this.avatarKey,
    required this.busy,
    required this.onTap,
  });

  final String? localPath;
  final String? photoUrl;
  final String? avatarKey;
  final bool busy;
  final VoidCallback? onTap;

  static const _diameter = 136.0;
  static const _badge = 38.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A just-picked file shows immediately; the uploaded URL only exists after
    // the round trip, and the avatar is the fallback for neither.
    final local = localPath;

    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: Stack(
        children: [
          if (local != null && local.isNotEmpty)
            ClipOval(
              child: Image.file(
                // ignore: avoid_dynamic_calls — a local path is a plain file.
                _fileOf(local),
                width: _diameter,
                height: _diameter,
                fit: BoxFit.cover,
              ),
            )
          else
            ProfileAvatar(
              photoUrl: (avatarKey?.isEmpty ?? true) ? photoUrl : null,
              avatarKey: avatarKey,
              diameter: _diameter,
            ),
          if (busy)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            right: 0,
            bottom: AppSpacing.sm,
            child: Material(
              color: colors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: _badge,
                  height: _badge,
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: AppSizes.iconMd,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kept out of the build so the `dart:io` import stays in one place.
File _fileOf(String path) => File(path);

/// A hairline either side of the word "Or".
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = Expanded(child: Divider(color: colors.border, thickness: 1));

    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'Or',
            style: context.text.bodyMedium?.copyWith(color: colors.textMuted),
          ),
        ),
        line,
      ],
    );
  }
}

/// The outlined "Select Avatar" card with a chevron.
class _SelectAvatarCard extends StatelessWidget {
  const _SelectAvatarCard({required this.avatarKey, required this.onTap});

  final String? avatarKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final preview = BundledAvatar.fromKey(avatarKey) ?? BundledAvatar.all.first;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: colors.primaryMuted),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            ClipOval(child: Image.asset(preview.asset, width: 48, height: 48)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Avatar',
                    style: context.text.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Choose a fun, personalized avatar',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: AppSizes.iconMd,
              color: colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Looks like a field, opens the date picker.
class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: IgnorePointer(
        child: TextField(
          controller: TextEditingController(text: value),
          decoration: InputDecoration(
            hintText: '0/01/2000',
            suffixIcon: Icon(
              Icons.calendar_today_outlined,
              size: AppSizes.iconMd,
              color: colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
