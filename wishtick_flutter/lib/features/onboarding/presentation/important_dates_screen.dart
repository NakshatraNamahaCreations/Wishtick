import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/date_entry_field.dart';
import '../../../core/widgets/success_banner.dart';
import '../domain/onboarding_options.dart';
import 'onboarding_flow_controller.dart';
import 'widgets/labelled_field.dart';
import 'widgets/onboarding_step_scaffold.dart';
import 'widgets/selection_footer.dart';

/// Anniversaries live in the past; upcoming one-offs a few years out.
DateTime get _earliestOccasion => DateTime(DateTime.now().year - 120);
DateTime get _latestOccasion => DateTime(DateTime.now().year + 5);

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
  String? _dateError;

  /// Bumped after every successful save so the date field's `Key` changes —
  /// it owns its own typed text internally, so this is what makes it clear
  /// itself back to empty along with [_date] rather than keep showing a
  /// date that was just saved and reset underneath it.
  int _dateFieldGeneration = 0;

  /// Null when no banner is showing. Bumped on every successful save so a
  /// fresh [SuccessBanner] (a new `Key`) mounts even if one is already
  /// mid-dwell from a save moments earlier, replaying the animation instead
  /// of being a no-op against the still-mounted one.
  int? _bannerGeneration;

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
        _dateError = null;
        _dateFieldGeneration++;
        _bannerGeneration = (_bannerGeneration ?? 0) + 1;
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
            const _OccasionCarousel(),
            const SizedBox(height: AppSpacing.xl),
            _AddDateCard(
              key: ValueKey(_dateFieldGeneration),
              name: _name,
              relation: _relation,
              occasionKey: _occasionKey,
              occasions: occasions,
              dateError: _dateError,
              busy: flow.busy,
              canSave: _formComplete && !flow.busy,
              onChanged: () => setState(() {}),
              onOccasion: (key) => setState(() => _occasionKey = key),
              onDateChanged: (date) => setState(() => _date = date),
              onDateError: (error) => setState(() => _dateError = error),
              onSave: _saveDate,
            ),
            if (_bannerGeneration != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SuccessBanner(
                key: ValueKey(_bannerGeneration),
                message: 'Date added successfully!',
                onDismissed: () => setState(() => _bannerGeneration = null),
              ),
            ],
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

/// Pill-shaped, white-filled field decoration for this card only — Figma
/// `199:10` draws every field here as a full stadium, on white, rather than
/// the app-wide theme's rounded-rect lavender fill (`app_theme.dart`'s
/// `inputDecorationTheme`, deliberately lavender so a field doesn't read as a
/// raised card on the beige page — a call this screen's white *is* a card
/// makes moot). Overriding per-field like this keeps that global decision
/// intact everywhere else instead of reopening it for the whole app.
///
/// Only fill, border and radius are set here; hint style, prefix-icon colour,
/// content padding and the rest keep coming from the ambient theme, which
/// already sampled to the same values this frame uses.
///
/// [showFocusRing] defaults on, matching the rest of the app: a `TextField`
/// growing a plum ring while the caret sits in it is expected typing
/// feedback. It is turned off for the Occasion dropdown below — selecting a
/// value from its menu hands focus back to the closed button, same as typing
/// leaves a TextField focused, but a dropdown has no caret to explain a ring
/// that then lingers indefinitely. Without this every other field reads
/// "resting" while whichever was picked last stays outlined, which is the
/// mismatch the border is meant to fix.
InputDecoration pillFieldDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefixIcon,
  bool showFocusRing = true,
}) {
  final colors = context.colors;
  OutlineInputBorder border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: BorderSide(color: color, width: width),
      );

  final enabled = border(colors.border);

  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: colors.surface,
    border: enabled,
    enabledBorder: enabled,
    focusedBorder: showFocusRing ? border(colors.primary, width: 1.5) : enabled,
  );
}

/// One photo of the occasion carousel — Figma `204:321`/`204:371`.
class _OccasionSlide {
  const _OccasionSlide(this.asset, this.caption);

  final String asset;
  final String caption;
}

/// The photo carousel above the add-a-date card: three occasion photos,
/// auto-advancing, with a caption and dot row matching the design.
class _OccasionCarousel extends StatefulWidget {
  const _OccasionCarousel();

  static const _slides = [
    _OccasionSlide('assets/images/Birthday.png', 'Birthday'),
    _OccasionSlide('assets/images/Anniversary.png', 'Anniversary'),
    _OccasionSlide('assets/images/Special_Moments.png', 'Special Moments'),
  ];

  /// The Figma frame's card measures 344×256 — this is that ratio, so the
  /// card keeps its proportions at any width instead of a fixed size that
  /// would either overflow a narrow phone or float undersized on a wide one.
  static const _aspectRatio = 344 / 256;

  @override
  State<_OccasionCarousel> createState() => _OccasionCarouselState();
}

class _OccasionCarouselState extends State<_OccasionCarousel> {
  final _controller = PageController();
  int _index = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-checked on every dependency change (not just once in initState) so
    // toggling the OS accessibility setting mid-session starts or stops the
    // rotation immediately rather than waiting for the screen to reopen.
    if (MediaQuery.disableAnimationsOf(context)) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(seconds: 5), _advance);
    }
  }

  void _advance(Timer _) {
    if (!mounted) return;
    final next = (_index + 1) % _OccasionCarousel._slides.length;
    _controller.animateToPage(
      next,
      duration: AppDurations.normal,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _OccasionCarousel._slides;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _OccasionCarousel._aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) =>
                      Image.asset(slides[i].asset, fit: BoxFit.cover),
                ),
                _CaptionScrim(caption: slides[_index].caption),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _CarouselDots(count: slides.length, index: _index),
      ],
    );
  }
}

/// The dark gradient and caption pinned to the bottom of the active photo.
class _CaptionScrim extends StatelessWidget {
  const _CaptionScrim({required this.caption});

  final String caption;

  /// Fraction of the card height the scrim rises to. Tall enough for the
  /// caption to sit on a legible background; short enough that most of the
  /// photo above it stays undimmed, as the reference shows.
  static const _heightFraction = 0.4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The overlay/scrim token ramped from transparent to itself, rather than
    // a literal black — see WishtickColors.overlay.
    final scrim = colors.overlay;

    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: _heightFraction,
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [scrim.withValues(alpha: 0), scrim],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                caption,
                style: context.text.headlineMedium?.copyWith(
                  color: colors.textOnDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three equal dots; the active one fills with the brand plum. Mirrors the
/// welcome carousel's `_Dots`, kept local rather than shared since neither
/// screen depends on the other and each is a handful of lines.
class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? colors.primary : colors.border,
            ),
          ),
      ],
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
    required this.dateError,
    required this.busy,
    required this.canSave,
    required this.onChanged,
    required this.onOccasion,
    required this.onDateChanged,
    required this.onDateError,
    required this.onSave,
    super.key,
  });

  final TextEditingController name;
  final TextEditingController relation;
  final String? occasionKey;
  final List<TaxonomyOption> occasions;
  final String? dateError;
  final bool busy;
  final bool canSave;
  final VoidCallback onChanged;
  final ValueChanged<String?> onOccasion;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<String?> onDateError;
  final VoidCallback onSave;

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
              // Container(
              //   width: 28,
              //   height: 28,
              //   decoration: BoxDecoration(
              //     shape: BoxShape.circle,
              //     color: colors.primary,
              //   ),
              //   child: Icon(
              //     Icons.add,
              //     size: AppSizes.iconMd,
              //     color: colors.onPrimary,
              //   ),
              // ),
              // const SizedBox(width: AppSpacing.md),
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
              decoration: pillFieldDecoration(
                context,
                hintText: 'e.g. Ananya, Rahul',
                prefixIcon: const Icon(Icons.person_outline),
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
              decoration: pillFieldDecoration(
                context,
                hintText: 'e.g. Mom, Best Friend',
                prefixIcon: const Icon(Icons.person_outline),
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
              decoration: pillFieldDecoration(context, showFocusRing: false),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          LabelledField(
            label: 'Occasion Date',
            errorText: dateError,
            child: DateEntryField(
              firstDate: _earliestOccasion,
              lastDate: _latestOccasion,
              pickerHelpText: 'Occasion date',
              onChanged: onDateChanged,
              onValidationError: onDateError,
              tooEarlyText: 'Please double-check the year',
              tooLateText: "That's a bit too far ahead",
              decoration: pillFieldDecoration(context),
              calendarIcon: Icon(
                Icons.calendar_today_outlined,
                size: AppSizes.iconMd,
                color: colors.textMuted,
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
