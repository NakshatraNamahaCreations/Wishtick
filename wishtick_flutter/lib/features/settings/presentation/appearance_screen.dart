import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_extensions.dart';

/// Profile → Appearance. Light / dark / follow-system, persisted immediately.
///
/// The Figma file is light-only, so this screen has no frame of its own; it
/// follows the list-row pattern of the Profile screen (`64:158`).
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      // Background inherits ThemeData.scaffoldBackgroundColor — see WishtickColors.background.
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                for (final option in ThemeMode.values)
                  _ThemeOptionTile(
                    mode: option,
                    selected: mode == option,
                    isLast: option == ThemeMode.values.last,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(option),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.mode,
    required this.selected,
    required this.isLast,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final bool isLast;
  final VoidCallback onTap;

  static const _labels = {
    ThemeMode.system: ('Use device setting', Icons.brightness_auto_outlined),
    ThemeMode.light: ('Light', Icons.light_mode_outlined),
    ThemeMode.dark: ('Dark', Icons.dark_mode_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, icon) = _labels[mode]!;

    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: colors.textSecondary),
          title: Text(label, style: context.text.titleMedium),
          trailing: selected
              ? Icon(Icons.check_circle, color: colors.primary)
              : Icon(Icons.circle_outlined, color: colors.border),
        ),
        if (!isLast) Divider(color: colors.border, indent: AppSpacing.lg),
      ],
    );
  }
}
