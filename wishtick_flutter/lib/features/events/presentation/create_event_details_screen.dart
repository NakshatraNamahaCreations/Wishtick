import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/date_entry_field.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import 'create_event_controller.dart';

/// The description counter on `257:755` reads "12/40".
const _kDescriptionMax = 400;

/// "Tell us about your event" (`257:755`) — step 2.
///
/// Next goes on to the invitation and sends nothing: the event is created
/// only once the host has seen the finished card and gone on to share it —
/// see [CreateEventController.publish].
class CreateEventDetailsScreen extends ConsumerStatefulWidget {
  const CreateEventDetailsScreen({super.key});

  @override
  ConsumerState<CreateEventDetailsScreen> createState() =>
      _CreateEventDetailsScreenState();
}

class _CreateEventDetailsScreenState
    extends ConsumerState<CreateEventDetailsScreen> {
  late final TextEditingController _title;
  late final TextEditingController _venue;
  late final TextEditingController _description;

  /// Set only while the manual-entry Event Date box holds a complete but
  /// impossible or out-of-range date — see [DateEntryField.onValidationError].
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final state = ref.read(createEventProvider);
    final notifier = ref.read(createEventProvider.notifier);

    // Seeded from step 1 the first time only — a title the host has edited is
    // never overwritten by a generated one.
    final seeded = state.title.isEmpty
        ? notifier.suggestedTitle()
        : state.title;
    _title = TextEditingController(text: seeded);
    _venue = TextEditingController(text: state.venue);
    _description = TextEditingController(text: state.description);
    if (state.title.isEmpty && seeded.isNotEmpty) {
      Future.microtask(() => notifier.setTitle(seeded));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onDateChanged(DateTime? value) {
    final notifier = ref.read(createEventProvider.notifier);
    if (value == null) {
      notifier.clearDate();
    } else {
      notifier.setDate(value);
    }
  }

  Future<void> _pickTime() async {
    final current = ref.read(createEventProvider).time;
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 19, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null || !mounted) return;
    ref
        .read(createEventProvider.notifier)
        .setTime(TimeOfDayValue(picked.hour, picked.minute));
  }

  void _next() => context.push<void>(AppRoutes.createEventInvite);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createEventProvider);
    final notifier = ref.read(createEventProvider.notifier);
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
          Text(
            'Tell us about\nyour event',
            // displaySmall, not headlineMedium: a page headline is Cormorant
            // Garamond in every frame, and `headline*` is Montserrat. Every
            // onboarding and auth screen already does it this way.
            style: context.text.displaySmall?.copyWith(
              color: context.headlineBrandColor,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Pick an occasion to create invitations, share wishlists, and '
            'celebrate together.',
            style: context.text.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.section),

          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            buildCounter: _noCounter,
            decoration: const InputDecoration(
              labelText: 'Event Name *',
              hintText: "Rahul & Priya's Anniversary",
            ),
            onChanged: notifier.setTitle,
          ),
          const SizedBox(height: AppSpacing.xl),

          DateEntryField(
            initialDate: state.date,
            firstDate: DateTime.now(),
            lastDate: DateTime(DateTime.now().year + 5),
            pickerInitialDate: DateTime.now().add(const Duration(days: 1)),
            onChanged: _onDateChanged,
            onValidationError: (error) => setState(() => _dateError = error),
            tooEarlyText: 'That date has already passed',
            tooLateText: "That's a bit too far ahead",
            decoration: InputDecoration(
              labelText: 'Event Date *',
              errorText: _dateError,
            ),
            calendarIcon: Icon(
              Icons.calendar_today_outlined,
              size: AppSizes.iconMd,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          _PickerField(
            label: 'Event Time *',
            value: state.time == null
                ? null
                : MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay(
                      hour: state.time!.hour,
                      minute: state.time!.minute,
                    ),
                  ),
            hint: '8:00 PM',
            icon: Icons.access_time,
            onTap: _pickTime,
          ),
          const SizedBox(height: AppSpacing.xl),

          TextField(
            controller: _venue,
            textCapitalization: TextCapitalization.words,
            maxLength: 200,
            buildCounter: _noCounter,
            decoration: const InputDecoration(
              labelText: 'Location *',
              hintText: 'Mysore Socials',
            ),
            onChanged: notifier.setVenue,
          ),
          const SizedBox(height: AppSpacing.xl),

          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 4,
            maxLength: _kDescriptionMax,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText:
                  "Let's make her day extra special. Join us in celebrating "
                  "Ananya's birthday.",
            ),
            onChanged: notifier.setDescription,
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
              onPressed: state.step2Complete ? _next : null,
              child: const Text('Next'),
            ),
          ),
        ),
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

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;
