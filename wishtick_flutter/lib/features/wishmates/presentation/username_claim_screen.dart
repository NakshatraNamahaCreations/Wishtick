import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/dismiss_keyboard_on_tap.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../../profile/presentation/profile_providers.dart';
import '../data/wishmates_repository.dart';

/// Claim a `@handle`.
///
/// **No frame in the WishMates set draws this screen, and every one of them
/// depends on it**: an account with no handle is not discoverable, cannot be
/// searched for and cannot be found by anyone it has not already met. The
/// handle is opt-in by design — nothing derives one from an email or a display
/// name, because that would publish a guessable, searchable identifier for
/// every existing user without anyone agreeing to it. So there has to be a
/// place to agree, and this is it.
///
/// Built in the idiom of the other single-field screens in the app rather than
/// invented: the page background, a circle-back app bar, one field, one pill.
class UsernameClaimScreen extends ConsumerStatefulWidget {
  const UsernameClaimScreen({super.key});

  @override
  ConsumerState<UsernameClaimScreen> createState() =>
      _UsernameClaimScreenState();
}

class _UsernameClaimScreenState extends ConsumerState<UsernameClaimScreen> {
  final _controller = TextEditingController();

  /// The last term an availability check was started for, so a late reply for
  /// an earlier one cannot overwrite the answer for what is on screen now.
  String _checking = '';

  bool? _available;
  bool _saving = false;
  String? _error;
  Timer? _debounce;

  /// Mirrors the server's rule exactly (`^[a-z0-9_]{3,30}$`). Checked here so
  /// the screen can say what is wrong before spending a round trip on it — the
  /// server is still the one that decides.
  static final _pattern = RegExp(r'^[a-z0-9_]{3,30}$');

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _value => _controller.text.trim().toLowerCase();

  String? get _localProblem {
    final value = _value;
    if (value.isEmpty) return null;
    if (value.length < 3) return 'A handle is at least 3 characters.';
    if (value.length > 30) return 'A handle is at most 30 characters.';
    if (!_pattern.hasMatch(value)) {
      return 'Letters, numbers and underscore only.';
    }
    return null;
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    setState(() {
      _available = null;
      _error = null;
    });
    if (_localProblem != null || _value.isEmpty) return;
    // Debounced: a check per keystroke would ask the server whether every
    // prefix of the handle is free, and the answer for "ro" tells you nothing
    // about "rohan".
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_check()),
    );
  }

  Future<void> _check() async {
    final term = _value;
    _checking = term;
    try {
      final available = await ref
          .read(wishmatesRepositoryProvider)
          .isUsernameAvailable(term);
      if (!mounted || _checking != term) return;
      setState(() => _available = available);
    } on ApiException {
      // Silent: an availability check is a convenience, and the claim below
      // gives a real answer. Saying "we could not check" under every keystroke
      // would be worse than saying nothing.
    }
  }

  Future<void> _claim() async {
    if (_localProblem != null || _value.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(wishmatesRepositoryProvider).setUsername(_value);
      // The handle lives on the profile, which the Profile hub and this
      // screen's own entry point both read.
      ref.invalidate(meProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // Branching on the code, never the message — the backend's own rule.
        _error = switch (e.code) {
          'USERNAME_TAKEN' => 'That handle is already taken.',
          'USERNAME_INVALID' =>
            'A handle is 3–30 characters: letters, numbers and underscore.',
          _ => e.message,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final problem = _localProblem;
    final canSubmit = problem == null && _value.isNotEmpty && !_saving;

    return DismissKeyboardOnTap(
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: circleBackAppBar(context, title: 'Your Handle'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick a handle',
                  style: context.text.headlineSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This is how WishMates find you. Until you choose one, '
                  'nobody can search for your account.',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 30,
                  textInputAction: TextInputAction.done,
                  onChanged: _onChanged,
                  onSubmitted: (_) => unawaited(_claim()),
                  inputFormatters: [
                    // Lower-cased as it is typed rather than on submit, so the
                    // handle on screen is the handle that gets claimed.
                    TextInputFormatter.withFunction(
                      (_, next) => next.copyWith(text: next.text.toLowerCase()),
                    ),
                  ],
                  style: context.text.titleMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixText: '@',
                    prefixStyle: context.text.titleMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                    hintText: 'rohan_prasad',
                    filled: true,
                    fillColor: colors.surface,
                    counterText: '',
                    suffixIcon: _suffix(colors),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: colors.primary),
                    ),
                  ),
                ),
                if (problem != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  WishtickErrorText(problem),
                ] else if (_available == false) ...[
                  const SizedBox(height: AppSpacing.sm),
                  WishtickErrorText('@$_value is already taken.'),
                ] else if (_available == true) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '@$_value is available.',
                    style: context.text.bodySmall?.copyWith(
                      color: colors.success,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  WishtickErrorText(_error!),
                ],
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: FilledButton(
                    onPressed: canSubmit ? () => unawaited(_claim()) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.cta,
                      foregroundColor: colors.onCta,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: AppSizes.iconMd,
                            height: AppSizes.iconMd,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onCta,
                            ),
                          )
                        : const Text('Claim Handle'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _suffix(dynamic colors) {
    if (_available == null) return null;
    return Icon(
      _available! ? Icons.check_circle_outline : Icons.cancel_outlined,
      color: _available! ? colors.success : colors.danger,
    );
  }
}
