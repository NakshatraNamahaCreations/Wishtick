import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../data/auth_repository.dart';
import 'sign_in_controller.dart';

/// OTP entry — Figma `17:530`.
///
/// Close button, serif headline, the number with an "edit" link, one box per
/// digit, a resend countdown, then "Verify".
///
/// The design draws four boxes but its own copy says "6-digit code", and the
/// backend issues six digits (`OTP_LENGTH=6`) — so six boxes are rendered. See
/// the note in sprints.md.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  static const _length = AuthRepository.otpLength;

  @override
  void initState() {
    super.initState();
    _field.addListener(_onChanged);
  }

  @override
  void dispose() {
    _field
      ..removeListener(_onChanged)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    if (_field.text.length == _length) _submit();
  }

  Future<void> _submit() async {
    await ref.read(signInControllerProvider.notifier).submitCode(_field.text);
    if (!mounted) return;
    // A rejected code should not leave the boxes full — clear so the next
    // attempt starts from an empty field.
    if (ref.read(signInControllerProvider).error != null) {
      _field.clear();
      _focus.requestFocus();
    }
  }

  void _onEdit() {
    ref.read(signInControllerProvider.notifier).editPhone();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(signInControllerProvider);
    final code = _field.text;

    // Completing sign-in flips the session to authenticated, and the router's
    // redirect takes over from there.
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: _CircleIconButton(
                  icon: Icons.close,
                  semanticLabel: 'Close',
                  onPressed: () => context.pop(),
                ),
              ),
              const SizedBox(height: AppSpacing.huge),
              Text(
                'Enter OTP',
                textAlign: TextAlign.center,
                style: AppTypography.displaySmall.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'We sent a $_length-digit code to your phone',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _NumberWithEdit(
                number: state.phone?.nationalNumber ?? '',
                onEdit: _onEdit,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _CodeBoxes(
                length: _length,
                code: code,
                hasError: state.error != null,
                field: _field,
                focus: _focus,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ResendRow(
                remaining: state.resendIn,
                canResend: state.canResend,
                onResend: () {
                  _field.clear();
                  ref.read(signInControllerProvider.notifier).resendCode();
                },
              ),
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                WishtickErrorText(state.error!),
                if (state.attemptsRemaining != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${state.attemptsRemaining} attempt'
                    '${state.attemptsRemaining == 1 ? '' : 's'} remaining',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: code.length == _length && !state.busy
                    ? _submit
                    : null,
                child: state.busy
                    ? SizedBox(
                        width: AppSizes.iconMd,
                        height: AppSizes.iconMd,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(colors.onPrimary),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: AppSizes.iconLg),
                          SizedBox(width: AppSpacing.sm),
                          Text('Verify'),
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

class _NumberWithEdit extends StatelessWidget {
  const _NumberWithEdit({required this.number, required this.onEdit});

  final String number;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          number,
          style: context.text.titleMedium?.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: onEdit,
          child: Text(
            'edit',
            style: context.text.bodyMedium?.copyWith(
              color: colors.celebration,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// One rounded box per digit, driven by a single hidden field.
///
/// A real [TextField] underneath (rather than one per box) is what lets the
/// platform's SMS autofill drop the whole code in at once.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.length,
    required this.code,
    required this.hasError,
    required this.field,
    required this.focus,
  });

  final int length;
  final String code;
  final bool hasError;
  final TextEditingController field;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: _Box(
                  digit: i < code.length ? code[i] : null,
                  focused: i == code.length,
                  hasError: hasError,
                ),
              ),
          ],
        ),
        // Invisible but real: holds focus, the caret and autofill.
        Opacity(
          opacity: 0,
          child: TextField(
            controller: field,
            focusNode: focus,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: length,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(counterText: ''),
          ),
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.digit,
    required this.focused,
    required this.hasError,
  });

  final String? digit;
  final bool focused;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = hasError
        ? colors.danger
        : (focused ? colors.primary : colors.border);

    return Container(
      width: 48,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border, width: focused || hasError ? 1.5 : 1),
      ),
      child: Text(
        digit ?? '',
        style: context.text.headlineSmall?.copyWith(color: colors.textPrimary),
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.remaining,
    required this.canResend,
    required this.onResend,
  });

  final Duration remaining;
  final bool canResend;
  final VoidCallback onResend;

  static String _mmss(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (canResend) {
      return Center(
        child: TextButton(
          onPressed: onResend,
          child: const Text('Resend code'),
        ),
      );
    }

    return Center(
      child: Text.rich(
        TextSpan(
          style: context.text.bodyMedium?.copyWith(color: colors.textMuted),
          children: [
            const TextSpan(text: 'Resend code in '),
            TextSpan(
              text: _mmss(remaining),
              style: TextStyle(
                color: colors.celebration,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceAlt,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: AppSizes.iconLg),
        color: colors.textPrimary,
        tooltip: semanticLabel,
      ),
    );
  }
}
