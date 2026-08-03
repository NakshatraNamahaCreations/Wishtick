import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
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

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final current = ref.read(profileFormProvider).draft.dateOfBirth;

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 25, now.month, now.day),
      // Nobody alive is older than this, and a birthday cannot be in the future.
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      ref.read(profileFormProvider.notifier).setDateOfBirth(picked);
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
                              onPickPhoto: _onPickPhoto,
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
                          const SizedBox(height: AppSpacing.huge),
                          LabelledField(
                            label: 'Email ID',
                            required: true,
                            errorText: state.fieldErrors['email'],
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
                          const SizedBox(height: AppSpacing.huge),
                          LabelledField(
                            label: 'Date of Birth',
                            required: true,
                            errorText: state.fieldErrors['dateOfBirth'],
                            child: _DateOfBirthField(
                              value: draft.dateOfBirthDisplay,
                              onTap: _pickDateOfBirth,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.huge),
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

  void _onPickPhoto() {
    // Uploading a photo needs the media presign → PUT → confirm round trip;
    // that lands with the profile-edit screen in Sprint 9. Until then the
    // bundled avatars are the supported route, so point at them rather than
    // opening a picker that cannot finish.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Photo upload arrives in Sprint 9 — pick an avatar below.',
        ),
      ),
    );
  }
}

class _PhotoCircle extends StatelessWidget {
  const _PhotoCircle({required this.avatar, required this.onPickPhoto});

  final BundledAvatar? avatar;
  final VoidCallback onPickPhoto;

  static const _diameter = 136.0;
  static const _badgeSize = 38.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The design always shows a face here, and the card below already previews
    // the same default — an empty circle with a person glyph made the two
    // disagree about what "no avatar chosen yet" looks like.
    final preview = avatar ?? BundledAvatar.all.first;

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
              child: Image.asset(preview.asset, fit: BoxFit.cover),
            ),
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
    final preview = avatar ?? BundledAvatar.all.first;

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

class _DateOfBirthField extends StatelessWidget {
  const _DateOfBirthField({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = value.isEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppSizes.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          // Matches the themed TextField fill so this hand-rolled field is
          // indistinguishable from its siblings.
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                empty ? 'dd/mm/yyyy' : value,
                style: context.text.bodyLarge?.copyWith(
                  color: empty ? colors.textMuted : colors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: AppSizes.iconMd,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
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
