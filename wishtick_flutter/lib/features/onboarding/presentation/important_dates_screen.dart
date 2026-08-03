import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/onboarding_options.dart';
import 'onboarding_flow_controller.dart';
import 'widgets/labelled_field.dart';
import 'widgets/onboarding_step_scaffold.dart';
import 'widgets/selection_footer.dart';

/// Step 5 — "Never Miss a Celebration" (Figma `199:10`; `204:321`/`204:371`
/// are its occasion-carousel states).
///
/// An add-a-date card (name, relationship, occasion, date, Save Date) with
/// each saved entry listed beneath, then SKIP / Continue. Continue completes
/// onboarding.
class ImportantDatesScreen extends ConsumerStatefulWidget {
  const ImportantDatesScreen({super.key});

  @override
  ConsumerState<ImportantDatesScreen> createState() =>
      _ImportantDatesScreenState();
}

class _ImportantDatesScreenState extends ConsumerState<ImportantDatesScreen> {
  final _name = TextEditingController();
  final _relation = TextEditingController();
  String? _occasionKey;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(onboardingFlowProvider.notifier).ensureOptions(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    super.dispose();
  }

  bool get _formComplete =>
      _name.text.trim().isNotEmpty &&
      _relation.text.trim().isNotEmpty &&
      _occasionKey != null &&
      _date != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      // Anniversaries live in the past; upcoming one-offs a few years out.
      firstDate: DateTime(now.year - 120),
      lastDate: DateTime(now.year + 5),
      helpText: 'Occasion date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _saveDate() async {
    final date = _date!;
    final iso =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final added = await ref
        .read(onboardingFlowProvider.notifier)
        .addDate(
          personName: _name.text.trim(),
          relation: _relation.text.trim(),
          occasionKey: _occasionKey!,
          dateIso: iso,
        );
    if (added && mounted) {
      setState(() {
        _name.clear();
        _relation.clear();
        _occasionKey = null;
        _date = null;
      });
    }
  }

  Future<bool> _finishWork() =>
      ref.read(onboardingFlowProvider.notifier).finish();

  void _afterFinish() {
    if (mounted) context.go(AppRoutes.onboardingDone);
  }

  /// SKIP stays a plain tap — same work, navigates immediately.
  Future<void> _finish() async {
    if (await _finishWork()) _afterFinish();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final flow = ref.watch(onboardingFlowProvider);
    final occasions = flow.options?.occasions ?? const <TaxonomyOption>[];

    return OnboardingStepScaffold(
      step: 5,
      headline: 'Never Miss a Celebration',
      subtitle:
          'Keep track of birthdays, anniversaries, and special moments so '
          'every gift arrives right on time.',
      onBack: () => context.go(AppRoutes.onboardingSizes),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AddDateCard(
              name: _name,
              relation: _relation,
              occasionKey: _occasionKey,
              occasions: occasions,
              date: _date,
              busy: flow.busy,
              canSave: _formComplete && !flow.busy,
              onChanged: () => setState(() {}),
              onOccasion: (key) => setState(() => _occasionKey = key),
              onPickDate: _pickDate,
              onSave: _saveDate,
            ),
            if (flow.savedDates.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              for (final saved in flow.savedDates) ...[
                _SavedDateTile(
                  date: saved,
                  occasionLabel:
                      occasions
                          .where((o) => o.key == saved.occasionKey)
                          .firstOrNull
                          ?.label ??
                      saved.occasionKey,
                  onDelete: () => ref
                      .read(onboardingFlowProvider.notifier)
                      .removeDate(saved.id),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: AppSizes.iconMd,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      "We'll remind you before each special day.",
                      style: context.text.bodySmall?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      footer: SelectionFooter(
        summary: null,
        onContinue: _finishWork,
        onContinueSucceeded: _afterFinish,
        onSkip: _finish,
        busy: flow.busy,
        error: flow.error,
      ),
    );
  }
}

/// The white "Add a new date" card.
class _AddDateCard extends StatelessWidget {
  const _AddDateCard({
    required this.name,
    required this.relation,
    required this.occasionKey,
    required this.occasions,
    required this.date,
    required this.busy,
    required this.canSave,
    required this.onChanged,
    required this.onOccasion,
    required this.onPickDate,
    required this.onSave,
  });

  final TextEditingController name;
  final TextEditingController relation;
  final String? occasionKey;
  final List<TaxonomyOption> occasions;
  final DateTime? date;
  final bool busy;
  final bool canSave;
  final VoidCallback onChanged;
  final ValueChanged<String?> onOccasion;
  final VoidCallback onPickDate;
  final VoidCallback onSave;

  String get _dateDisplay {
    final d = date;
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary,
                ),
                child: Icon(
                  Icons.add,
                  size: AppSizes.iconMd,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Add a new date',
                style: context.text.headlineSmall?.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          LabelledField(
            label: 'Enter Name',
            child: TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                hintText: 'e.g. Ananya, Rahul',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LabelledField(
            label: 'Relationship',
            child: TextField(
              controller: relation,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                hintText: 'e.g. Mom, Best Friend',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LabelledField(
            label: 'Occasion',
            child: DropdownButtonFormField<String>(
              initialValue: occasionKey,
              items: [
                for (final occasion in occasions)
                  DropdownMenuItem(
                    value: occasion.key,
                    child: Text(occasion.label),
                  ),
              ],
              onChanged: onOccasion,
              hint: const Text('Birthday'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LabelledField(
            label: 'Occasion Date',
            child: GestureDetector(
              onTap: onPickDate,
              child: Container(
                height: AppSizes.inputHeight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dateDisplay.isEmpty ? 'dd/mm/yyyy' : _dateDisplay,
                        style: context.text.bodyLarge?.copyWith(
                          color: _dateDisplay.isEmpty
                              ? colors.textMuted
                              : colors.textPrimary,
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
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSave ? onSave : null,
              child: busy
                  ? SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(colors.onPrimary),
                      ),
                    )
                  : const Text('Save Date'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedDateTile extends StatelessWidget {
  const _SavedDateTile({
    required this.date,
    required this.occasionLabel,
    required this.onDelete,
  });

  final ImportantDate date;
  final String occasionLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.cake_outlined, color: colors.celebration),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.personName} · $occasionLabel',
                  style: context.text.titleSmall?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  '${date.relation} · ${date.date}',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline,
              size: AppSizes.iconMd,
              color: colors.textMuted,
            ),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
