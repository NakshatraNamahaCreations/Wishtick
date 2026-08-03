import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/phone_number.dart';
import 'sign_in_controller.dart';

/// Mobile number entry — Figma `17:329` (and `143:141`, the same screen with the
/// keyboard raised and a number typed).
///
/// Sparkle badge, gradient serif headline, body copy, a phone field with the
/// country dial code fixed on the left, then "GET OTP" which stays disabled
/// until the number is complete.
class MobileNumberScreen extends ConsumerStatefulWidget {
  const MobileNumberScreen({super.key});

  @override
  ConsumerState<MobileNumberScreen> createState() => _MobileNumberScreenState();
}

class _MobileNumberScreenState extends ConsumerState<MobileNumberScreen> {
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    // Pre-fill when coming back from the OTP step to correct the number.
    final existing = ref.read(signInControllerProvider).phone;
    _field = TextEditingController(text: existing?.nationalNumber ?? '');
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    ref
        .read(signInControllerProvider.notifier)
        .setPhone(PhoneNumber.parse(raw));
  }

  Future<void> _submit() async {
    final controller = ref.read(signInControllerProvider.notifier);
    await controller.requestCode();
    if (!mounted) return;
    if (ref.read(signInControllerProvider).step == SignInStep.code) {
      // Pushed, not replaced: the OTP screen's close button returns here.
      unawaited(context.push(AppRoutes.otp));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(signInControllerProvider);
    final ready = state.phone?.isComplete ?? false;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.huge),
              const _SparkleBadge(),
              const SizedBox(height: AppSpacing.lg),
              _GradientHeadline('Ready to Celebrate?'),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sign in to create wishlists, celebrate together, and surprise '
                'the people who matter most.',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _PhoneField(
                controller: _field,
                dialCode: state.phone?.dialCode ?? PhoneNumber.defaultDialCode,
                onChanged: _onChanged,
                onSubmitted: ready ? (_) => _submit() : null,
              ),
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                WishtickErrorText(state.error!),
              ],
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: ready && !state.busy ? _submit : null,
                child: state.busy
                    ? const _ButtonSpinner()
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('GET OTP'),
                          SizedBox(width: AppSpacing.sm),
                          Icon(Icons.arrow_forward, size: AppSizes.iconMd),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// The circular sparkle mark above the headline.
class _SparkleBadge extends StatelessWidget {
  const _SparkleBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceAlt,
      ),
      child: Icon(Icons.auto_awesome, size: 22, color: colors.primary),
    );
  }
}

/// The headline runs plum → bronze left to right in the design.
class _GradientHeadline extends StatelessWidget {
  const _GradientHeadline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          context.gradients.headline.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        textAlign: TextAlign.center,
        // srcIn replaces this with the shader; it only has to be opaque.
        style: AppTypography.displaySmall.copyWith(
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.dialCode,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String dialCode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: AppSizes.inputHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.lg),
          // The country is fixed to India for launch; PhoneNumber already
          // carries a dial code so a picker slots in here later.
          const Text('🇮🇳', style: TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            dialCode,
            style: context.text.titleMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(width: 1, height: 24, color: colors.border),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              keyboardType: TextInputType.phone,
              autofocus: true,
              maxLength: PhoneNumber.nationalLengthFor(dialCode),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: context.text.titleMedium,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Enter your Mobile Number',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.iconMd,
      height: AppSizes.iconMd,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation(context.colors.onPrimary),
      ),
    );
  }
}
