import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/date_entry_field.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../../core/widgets/wishtick_swipe_button.dart';
import '../data/onboarding_repository.dart';
import '../domain/profile_draft.dart';
import 'profile_controller.dart';
import 'widgets/gender_selector.dart';
import 'widgets/labelled_field.dart';
import 'widgets/onboarding_progress.dart';

/// Create Your Profile — Figma `31:608`, onboarding step 1 of 5.
///
/// Progress header, serif headline, a photo circle with a camera button, the
/// "Or / Select Avatar" card, then name, email, date of birth and gender, with a
/// terms line above the Continue pill.
class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;

  /// Set only while the manual-entry Date of Birth box holds a complete but
  /// impossible or out-of-range date ("31/02/2020", a birth year in the
  /// future, ...) — see [DateEntryField.onValidationError].
  String? _dobError;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileFormProvider).draft;
    _name = TextEditingController(text: draft.name);
    _email = TextEditingController(text: draft.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Nobody alive is older than this, and a birthday cannot be in the
  /// future — matches [DateEntryField.firstDate]/`lastDate` below.
  static DateTime get _earliestDob => DateTime(DateTime.now().year - 120);

  void _onDobChanged(DateTime? value) {
    final notifier = ref.read(profileFormProvider.notifier);
    if (value == null) {
      notifier.clearDateOfBirth();
    } else {
      notifier.setDateOfBirth(value);
    }
  }

  Future<bool> _submit() => ref.read(profileFormProvider.notifier).submit();

  void _afterSubmit() {
    if (!mounted) return;
    // Step 1 saved — on to "Tell us what you love" (step 2).
    context.go(AppRoutes.onboardingInterests);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(profileFormProvider);
    final draft = state.draft;

    return Scaffold(
      // Background inherits ThemeData.scaffoldBackgroundColor — see WishtickColors.background.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  // The back button sits at a 16 gutter while the content sits
                  // at 26, so it breaks out of the content padding below.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _CircleBack(onPressed: () => context.pop()),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenGutter,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OnboardingProgress(
                            step: OnboardingRepository.positionOf(
                              OnboardingRepository.stepProfile,
                            ),
                            totalSteps: OnboardingRepository.stepCount,
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          Text(
                            'Create Your Profile',
                            style: AppTypography.displaySmall.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            "A few details and you're in.",
                            style: context.text.bodyLarge?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          Center(
                            child: _PhotoCircle(
                              avatar: draft.avatar,
                              localPath: state.photoLocalPath,
                              busy: state.uploadingPhoto,
                              onPickPhoto: state.uploadingPhoto
                                  ? null
                                  : () => unawaited(_onPickPhoto()),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          const _OrDivider(),
                          const SizedBox(height: AppSpacing.xxl),
                          _SelectAvatarCard(
                            avatar: draft.avatar,
                            onTap: () => unawaited(
                              context.push(AppRoutes.onboardingAvatar),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),
                          LabelledField(
                            label: 'Your Name',
                            required: true,
                            errorText: state.fieldErrors['displayName'],
                            child: _FieldShadow(
                              child: TextField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                onChanged: ref
                                    .read(profileFormProvider.notifier)
                                    .setName,
                                decoration: const InputDecoration(
                                  hintText: 'Enter your full name',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    size: AppSizes.iconMd,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          LabelledField(
                            label: 'Email ID',
                            required: true,
                            errorText: state.fieldErrors['email'],
                            child: _FieldShadow(
                              child: TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                onChanged: ref
                                    .read(profileFormProvider.notifier)
                                    .setEmail,
                                decoration: const InputDecoration(
                                  hintText: 'Enter your Email ID',
                                  prefixIcon: Icon(
                                    Icons.mail_outline,
                                    size: AppSizes.iconMd,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          LabelledField(
                            label: 'Date of Birth',
                            required: true,
                            errorText:
                                _dobError ?? state.fieldErrors['dateOfBirth'],
                            child: _FieldShadow(
                              child: Container(
                                height: AppSizes.inputHeight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                ),
                                decoration: BoxDecoration(
                                  // Matches the themed TextField fill so
                                  // this hand-rolled field is
                                  // indistinguishable from its siblings.
                                  color: colors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                child: DateEntryField(
                                  initialDate: draft.dateOfBirth,
                                  firstDate: _earliestDob,
                                  lastDate: DateTime.now(),
                                  pickerInitialDate: DateTime(
                                    DateTime.now().year - 25,
                                  ),
                                  pickerHelpText: 'Date of birth',
                                  onChanged: _onDobChanged,
                                  onValidationError: (error) =>
                                      setState(() => _dobError = error),
                                  tooEarlyText: 'Please double-check the year',
                                  tooLateText: "That's still in the future",
                                  style: context.text.bodyLarge?.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    hintStyle: context.text.bodyLarge?.copyWith(
                                      color: colors.textMuted,
                                    ),
                                  ),
                                  calendarIcon: Icon(
                                    Icons.calendar_today_outlined,
                                    size: AppSizes.iconMd,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          LabelledField(
                            label: 'Gender',
                            required: true,
                            errorText: state.fieldErrors['gender'],
                            child: GenderSelector(
                              value: draft.gender,
                              onChanged: ref
                                  .read(profileFormProvider.notifier)
                                  .setGender,
                            ),
                          ),
                          if (state.error != null) ...[
                            const SizedBox(height: AppSpacing.xl),
                            WishtickErrorText(state.error!),
                          ],
                          const SizedBox(height: AppSpacing.xxxl),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                0,
                AppSpacing.screenGutter,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TermsLine(),
                  const SizedBox(height: AppSpacing.xxl),
                  WishtickSwipeButton(
                    // Enabled on an empty form, as the design shows it —
                    // swiping validates and surfaces per-field errors, which
                    // tells the user more than an inert grey track does.
                    onSwiped: _submit,
                    onSuccess: _afterSubmit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Picks a photo, uploads it, and points the draft at the confirmed media.
  ///
  /// The same presign → PUT → confirm round trip Edit Profile (`90:21`) uses;
  /// this screen sat on a "coming in Sprint 9" snackbar until a device walk
  /// found the camera badge still inert after that sprint had shipped the
  /// upload everywhere else.
  Future<void> _onPickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (picked == null) return;

    final notifier = ref.read(profileFormProvider.notifier);
    notifier.setUploadingPhoto(true);
    try {
      final media = await ref
          .read(mediaRepositoryProvider)
          .uploadFile(
            file: picked,
            purpose: MediaPurpose.profilePhoto,
            fileName: picked.name,
          );
      notifier.setPhoto(media.id, localPath: picked.path);
    } catch (_) {
      notifier.failPhoto('Could not upload that photo.');
    } finally {
      notifier.setUploadingPhoto(false);
    }
  }
}

class _PhotoCircle extends StatelessWidget {
  const _PhotoCircle({
    required this.avatar,
    required this.onPickPhoto,
    this.localPath,
    this.busy = false,
  });

  final BundledAvatar? avatar;
  final VoidCallback? onPickPhoto;

  /// A just-picked file. Wins over [avatar] — the two are mutually exclusive
  /// server-side, and picking one clears the other.
  final String? localPath;
  final bool busy;

  static const _diameter = 136.0;
  static const _badgeSize = 38.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The design always shows a face here, and the card below previews the same
    // one. Both now read the draft straight through: the form seeds
    // [BundledAvatar.defaultChoice], so there is no "nothing chosen" state left
    // for a preview to paper over — which is what used to let somebody submit a
    // face they never actually saved.
    final preview = avatar ?? BundledAvatar.defaultChoice;

    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: Stack(
        children: [
          Container(
            width: _diameter,
            height: _diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface,
            ),
            child: ClipOval(
              child: localPath == null
                  ? Image.asset(preview.asset, fit: BoxFit.cover)
                  : Image.file(File(localPath!), fit: BoxFit.cover),
            ),
          ),
          if (busy)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            right: 0,
            bottom: AppSpacing.xs,
            child: Material(
              // A brighter violet than the Continue pill, per the export.
              color: colors.primaryMuted,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPickPhoto,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: _badgeSize,
                  height: _badgeSize,
                  child: Icon(
                    Icons.photo_camera,
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  /// The rules are short and centred — measured at ~58 each, so the assembly
  /// spans ~164 of the 340 content width rather than reaching the margins.
  static const _ruleWidth = 58.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rule = SizedBox(
      width: _ruleWidth,
      child: Divider(color: colors.textMuted),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        rule,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Or',
            style: context.text.bodyMedium?.copyWith(color: colors.textMuted),
          ),
        ),
        rule,
      ],
    );
  }
}

class _SelectAvatarCard extends StatelessWidget {
  const _SelectAvatarCard({required this.avatar, required this.onTap});

  final BundledAvatar? avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final preview = avatar ?? BundledAvatar.defaultChoice;

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            // No fill: the page shows through, so the card is defined by its
            // hairline alone. A white fill made it read as an input field.
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.outline),
          ),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  preview.asset,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Avatar',
                      style: context.text.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                color: colors.primary,
                size: AppSizes.iconMd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lifts a field off the page with a soft drop shadow — not in the Figma
/// export (a flattened static image cannot carry a shadow effect), but the
/// same treatment on Name, Email and Date of Birth keeps them reading as one
/// matching set.
class _FieldShadow extends StatelessWidget {
  const _FieldShadow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TermsLine extends StatelessWidget {
  const _TermsLine();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Text.rich(
      TextSpan(
        style: context.text.bodySmall?.copyWith(color: colors.textMuted),
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'Terms & Privacy.',
            style: TextStyle(
              color: colors.celebration,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack({required this.onPressed});

  final VoidCallback onPressed;

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.chevron_left, size: AppSizes.iconMd),
        color: colors.textPrimary,
        tooltip: 'Back',
        padding: EdgeInsets.zero,
        // Ø36 visually, per the export. IconButton's default padded tap target
        // still extends the touch area to the 48pt accessibility floor, so
        // shrinking the circle does not shrink what you can hit.
        constraints: const BoxConstraints.tightFor(width: _size, height: _size),
      ),
    );
  }
}
