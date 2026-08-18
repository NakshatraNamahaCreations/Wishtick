import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';
import 'notification_providers.dart';

/// "Notification Settings" — the row on the Profile hub (`64:158`).
///
/// A grid of category × channel switches over the server's opt-out set, plus
/// quiet hours and thank-you auto-send. In-app is not switchable: it *is* the
/// notification centre, and turning it off would leave a screen that could
/// never fill.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _saving = false;

  Future<void> _apply(Future<void> Function() call) async {
    setState(() => _saving = true);
    try {
      await call();
      ref.invalidate(notificationPreferencesProvider);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final prefs = ref.watch(notificationPreferencesProvider);
    final repo = ref.read(notificationsRepositoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context, title: 'Notification Settings'),
      // Deliberately not `prefs.when`: every toggle invalidates the provider,
      // which sends it back to `loading` — and on the device that blanked the
      // whole list to a spinner mid-flip and swallowed the next tap. Reading
      // `prefs.value` keeps the last-known settings on screen while the
      // refetch runs, so only the very first load shows a spinner.
      body: switch ((prefs.value, prefs.hasError)) {
        (null, true) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(notificationPreferencesProvider),
            child: const Text('Try again'),
          ),
        ),
        (null, false) => const Center(child: CircularProgressIndicator()),
        (final value?, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _Heading('WHAT YOU HEAR ABOUT'),
            const SizedBox(height: AppSpacing.md),
            for (final category in NotificationCategory.values)
              _CategoryCard(
                category: category,
                prefs: value,
                enabled: !_saving,
                onToggle: (channel, on) => unawaited(
                  _apply(
                    () => repo
                        .updatePreferences(
                          disabled: value.toggled(category, channel, on: on),
                        )
                        .then((_) {}),
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.xl),
            _Heading('QUIET HOURS'),
            const SizedBox(height: AppSpacing.md),
            _Card(
              child: SwitchListTile(
                value: value.quietHoursEnabled,
                onChanged: _saving
                    ? null
                    : (on) => unawaited(
                        _apply(
                          () => repo
                              .updatePreferences(
                                quietHoursEnabled: on,
                                // Sensible defaults the first time it is
                                // switched on; the server keeps them after.
                                quietStartHour: value.quietStartHour ?? 22,
                                quietEndHour: value.quietEndHour ?? 8,
                              )
                              .then((_) {}),
                        ),
                      ),
                title: Text(
                  'Hold notifications overnight',
                  style: context.text.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  value.quietHoursEnabled &&
                          value.quietStartHour != null &&
                          value.quietEndHour != null
                      ? 'Held between ${_hour(value.quietStartHour!)} and '
                            '${_hour(value.quietEndHour!)}'
                      : 'Anything urgent still arrives in the morning.',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            _Heading('THANK-YOU NOTES'),
            const SizedBox(height: AppSpacing.md),
            _Card(
              child: SwitchListTile(
                value: value.thankYouAutoSend,
                onChanged: _saving
                    ? null
                    : (on) => unawaited(
                        _apply(
                          () => repo
                              .updatePreferences(thankYouAutoSend: on)
                              .then((_) {}),
                        ),
                      ),
                title: Text(
                  'Send my thank-you notes automatically',
                  style: context.text.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Off means a note waits as a draft until you send it.',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      },
    );
  }

  static String _hour(int hour) {
    final suffix = hour < 12 ? 'am' : 'pm';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display$suffix';
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.prefs,
    required this.enabled,
    required this.onToggle,
  });

  final NotificationCategory category;
  final NotificationPreferences prefs;
  final bool enabled;
  final void Function(NotificationChannel channel, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.label,
                style: context.text.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.lg,
                children: [
                  for (final channel in NotificationChannel.switchable)
                    _ChannelToggle(
                      label: channel.label,
                      value: prefs.isOn(category, channel),
                      onChanged: enabled ? (on) => onToggle(channel, on) : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelToggle extends StatelessWidget {
  const _ChannelToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Switch(value: value, onChanged: onChanged),
      const SizedBox(width: AppSpacing.xs),
      Text(
        label,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.text.bodyMedium?.copyWith(
      color: context.headlineBrandColor,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: child,
  );
}
