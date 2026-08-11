import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import 'create_memory_controller.dart';
import 'memory_providers.dart';

/// "When should this Memory Unlock?" (`2198:73`) — step 2 of two.
///
/// The instant it captures is the whole feature: until it passes, nothing
/// inside the capsule is readable by anyone, its host included.
class CreateMemoryUnlockScreen extends ConsumerStatefulWidget {
  const CreateMemoryUnlockScreen({super.key});

  @override
  ConsumerState<CreateMemoryUnlockScreen> createState() =>
      _CreateMemoryUnlockScreenState();
}

class _CreateMemoryUnlockScreenState
    extends ConsumerState<CreateMemoryUnlockScreen> {
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = ref.read(createMemoryProvider).unlockDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now.add(const Duration(days: 1)),
      // An instant in the past is not a surprise, and the server refuses one —
      // so the picker refuses it first.
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    ref.read(createMemoryProvider.notifier).setUnlockDate(picked);
  }

  Future<void> _pickTime() async {
    final current = ref.read(createMemoryProvider).unlockTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 0, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null || !mounted) return;
    ref
        .read(createMemoryProvider.notifier)
        .setUnlockTime(MemoryTimeOfDay(picked.hour, picked.minute));
  }

  Future<void> _submit() async {
    final capsule = await ref.read(createMemoryProvider.notifier).submit();
    if (capsule == null || !mounted) return;
    // The tab is what "Created By You" reads from.
    ref.invalidate(myMemoriesProvider);
    context.go(AppRoutes.memory(capsule.id));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createMemoryProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: circleBackAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        children: [
          const SizedBox(height: AppSpacing.xxl),
          const Center(child: _GiftClockMark()),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'When should this\nMemory Unlock?',
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSpacing.section),

          _PickerField(
            label: 'Unlock Date *',
            value: state.unlockDate == null
                ? null
                : DateFormat('d - MMM - yyyy').format(state.unlockDate!),
            hint: '19 - Jul - 2026',
            icon: Icons.calendar_today_outlined,
            onTap: _pickDate,
          ),
          const SizedBox(height: AppSpacing.xl),
          _PickerField(
            label: 'Unlock Time *',
            value: state.unlockTime == null
                ? null
                : MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay(
                      hour: state.unlockTime!.hour,
                      minute: state.unlockTime!.minute,
                    ),
                  ),
            hint: '12:00 AM',
            icon: Icons.access_time,
            onTap: _pickTime,
          ),

          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            WishtickErrorText(state.error!),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.step2Complete && !state.busy ? _submit : null,
              child: state.busy
                  ? SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Text('Save & Continue'),
            ),
          ),
        ),
      ),
    );
  }
}

/// The gift-and-clock illustration `2198:73` leads with.
///
/// Drawn from two glyphs rather than the exported artwork, which is not in
/// `UI_Screen` — the same substitution the occasion tiles make.
class _GiftClockMark extends StatelessWidget {
  const _GiftClockMark();

  static const _size = 148.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          Center(
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: colors.optionFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_giftcard,
                size: _size * 0.5,
                color: colors.primaryMuted,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.primaryMuted, width: 2),
              ),
              child: Icon(
                Icons.schedule,
                size: AppSizes.iconLg,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A read-only field that opens a picker — date and time.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: context.text.bodyLarge?.copyWith(
                  color: value == null ? colors.textMuted : colors.textPrimary,
                ),
              ),
            ),
            Icon(icon, size: AppSizes.iconMd, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
