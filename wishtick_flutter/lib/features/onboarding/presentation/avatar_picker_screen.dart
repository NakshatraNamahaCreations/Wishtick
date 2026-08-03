import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_swipe_button.dart';
import '../domain/profile_draft.dart';
import 'profile_controller.dart';

/// Avatar picker — Figma `195:131`.
///
/// A four-column grid of the twenty bundled avatars, with a plum "Continue" pill
/// pinned to the bottom.
class AvatarPickerScreen extends ConsumerStatefulWidget {
  const AvatarPickerScreen({super.key});

  @override
  ConsumerState<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends ConsumerState<AvatarPickerScreen> {
  BundledAvatar? _selected;

  @override
  void initState() {
    super.initState();
    // Start on whatever the form already holds, so reopening shows the choice.
    _selected = ref.read(profileFormProvider).draft.avatar;
  }

  Future<bool> _confirm() async {
    final selected = _selected;
    if (selected == null) return false;
    ref.read(profileFormProvider.notifier).setAvatar(selected);
    return true;
  }

  void _afterConfirm() {
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      // Background inherits ThemeData.scaffoldBackgroundColor — see WishtickColors.background.
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BackButton(onPressed: () => context.pop()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xl,
                bottom: AppSpacing.xxxl,
              ),
              child: Text(
                'Select Your Avatar',
                textAlign: TextAlign.center,
                style: AppTypography.displaySmall.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
                // Ø70 circles on a 90 column pitch and a 110 row pitch — the
                // rows are twice as far apart as the columns.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: AppSpacing.xl,
                  mainAxisSpacing: AppSpacing.huge,
                ),
                itemCount: BundledAvatar.all.length,
                itemBuilder: (context, i) {
                  final avatar = BundledAvatar.all[i];
                  return _AvatarTile(
                    avatar: avatar,
                    selected: avatar == _selected,
                    onTap: () => setState(() => _selected = avatar),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.xxl,
                AppSpacing.screenGutter,
                AppSpacing.lg,
              ),
              child: WishtickSwipeButton(
                onSwiped: _selected == null ? null : _confirm,
                onSuccess: _afterConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  final BundledAvatar avatar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Avatar ${avatar.index}',
      child: GestureDetector(
        onTap: onTap,
        // The ring is drawn *over* the image rather than around it. A Border
        // on the container insets its child, so selecting an avatar used to
        // shrink it by 10px and the grid visibly jittered.
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface,
              ),
              child: ClipOval(
                child: Image.asset(avatar.asset, fit: BoxFit.cover),
              ),
            ),
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.primary, width: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

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
        // Ø36 visually; the padded tap target keeps the touch area at 48.
        constraints: const BoxConstraints.tightFor(width: _size, height: _size),
      ),
    );
  }
}
