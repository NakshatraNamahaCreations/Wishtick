import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/sparkle_icon.dart';
import '../domain/onboarding_options.dart';
import 'onboarding_flow_controller.dart';
import 'widgets/photo_tile_grid.dart';
import 'widgets/selection_footer.dart';

/// One category's granular-interest screen (Figma `204:471`, `238:4`, … —
/// the "Other" category renders the custom-interest variant `239:454`).
///
/// These sit *between* steps: a thin gold progress bar instead of the hearts
/// header, per the design. Continue/SKIP advance through the queue of selected
/// categories; after the last one, step 2 is saved and the flow moves to
/// colours.
class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({required this.categoryKey, super.key});

  final String categoryKey;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  final _custom = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(onboardingFlowProvider.notifier).ensureOptions(),
    );
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  bool get _isOther => widget.categoryKey == 'other';

  /// Where this screen sits in the queue of selected categories.
  (int, int) _queuePosition() {
    final queue = ref.read(onboardingFlowProvider).detailQueue;
    final index = queue.indexOf(widget.categoryKey);
    return (index < 0 ? 0 : index, queue.length);
  }

  bool get _isLastInQueue {
    final queue = ref.read(onboardingFlowProvider).detailQueue;
    final index = queue.indexOf(widget.categoryKey);
    return index < 0 || index == queue.length - 1;
  }

  /// The persistence step, if any — advancing to the next queued category is
  /// purely local and has nothing to await.
  Future<bool> _advanceWork() {
    if (!_isLastInQueue) return Future.value(true);
    // Last detail — persist step 2 before handing over to colours.
    return ref.read(onboardingFlowProvider.notifier).saveInterests();
  }

  void _afterAdvance() {
    if (!mounted) return;
    if (!_isLastInQueue) {
      final queue = ref.read(onboardingFlowProvider).detailQueue;
      final index = queue.indexOf(widget.categoryKey);
      context.push(AppRoutes.onboardingInterestDetail(queue[index + 1]));
      return;
    }
    context.go(AppRoutes.onboardingColors);
  }

  /// SKIP stays a plain tap — same underlying work, but fires and navigates
  /// immediately rather than through the swipe button's check-and-dwell.
  Future<void> _advance() async {
    if (await _advanceWork()) _afterAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final flow = ref.watch(onboardingFlowProvider);
    final options = flow.options;
    final (queueIndex, queueLength) = _queuePosition();

    final category = options?.interestCategories
        .where((c) => c.key == widget.categoryKey)
        .firstOrNull;
    final picks = flow.selectedInterests[widget.categoryKey] ?? const [];

    return Scaffold(
      // Background inherits ThemeData.scaffoldBackgroundColor.
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          _CircleBack(onPressed: () => context.pop()),
                          const SizedBox(height: AppSpacing.xl),
                          _SegmentProgress(
                            index: queueIndex,
                            total: queueLength,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            _isOther
                                ? 'Anything Else You Love?'
                                : (category?.label ?? ''),
                            style: AppTypography.displaySmall.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _isOther
                                ? 'Help us discover more about your interests '
                                      'for even better gift ideas.'
                                : 'Select the things you love most so we can '
                                      'recommend gifts that truly match your '
                                      'style.',
                            style: context.text.bodyLarge?.copyWith(
                              color: colors.primaryMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                    if (_isOther)
                      _CustomInterestBody(controller: _custom)
                    else if (options != null)
                      PhotoTileGrid(
                        options: options.interestsFor(widget.categoryKey),
                        selectedKeys: picks.toSet(),
                        onToggle: (key) => ref
                            .read(onboardingFlowProvider.notifier)
                            .toggleInterest(widget.categoryKey, key),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
            SelectionFooter(
              summary: _isOther
                  ? (flow.customInterests.isEmpty
                        ? null
                        : '(${flow.customInterests.length})')
                  : (picks.isEmpty
                        ? null
                        : '(${picks.length}/${OnboardingCaps.interestsPerCategory})'),
              onClearAll: _isOther || picks.isEmpty
                  ? null
                  : () => ref
                        .read(onboardingFlowProvider.notifier)
                        .clearInterests(widget.categoryKey),
              onContinue:
                  (_isOther
                      ? flow.customInterests.isNotEmpty
                      : picks.isNotEmpty)
                  ? _advanceWork
                  : null,
              onContinueSucceeded: _afterAdvance,
              onSkip: _advance,
              busy: flow.busy,
              error: flow.error,
            ),
          ],
        ),
      ),
    );
  }
}

/// The thin gold segmented progress bar the detail screens use instead of the
/// hearts header — one segment per selected category.
class _SegmentProgress extends StatelessWidget {
  const _SegmentProgress({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final segments = total < 1 ? 1 : total;

    return Row(
      children: [
        for (var i = 0; i < segments; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: i <= index ? colors.celebration : colors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The "Add a Custom Interest" card plus suggested tiles (Figma `239:454`).
class _CustomInterestBody extends ConsumerWidget {
  const _CustomInterestBody({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final flow = ref.watch(onboardingFlowProvider);
    final suggested = flow.options?.interestsFor('other') ?? const [];
    // A tapped suggestion becomes a custom entry by label, matching the
    // design's single "added" model for this screen.
    final chosen = flow.customInterests.toSet();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SparkleIcon(size: AppSizes.iconMd, color: colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Add a Custom Interest',
                      style: context.text.titleMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: controller,
                  maxLength: 40,
                  maxLines: 2,
                  minLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Type your interest here....',
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Be specific so we can personalize your gift '
                  'recommendation better.',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () {
                      ref
                          .read(onboardingFlowProvider.notifier)
                          .addCustomInterest(controller.text);
                      controller.clear();
                    },
                    child: const Text('+ Add Interest'),
                  ),
                ),
              ],
            ),
          ),
          if (flow.customInterests.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final custom in flow.customInterests)
                  Chip(
                    label: Text(custom),
                    onDeleted: () => ref
                        .read(onboardingFlowProvider.notifier)
                        .removeCustomInterest(custom),
                  ),
              ],
            ),
          ],
          if (suggested.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Suggested',
              style: context.text.headlineSmall?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Suggested tiles behave as one-tap customs: selecting adds the
            // label to the custom list, matching the screen's single model.
            Padding(
              // PhotoTileGrid pads horizontally itself; cancel the outer pad.
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: _SuggestedGrid(suggested: suggested, chosenLabels: chosen),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestedGrid extends ConsumerWidget {
  const _SuggestedGrid({required this.suggested, required this.chosenLabels});

  final List<TaxonomyOption> suggested;
  final Set<String> chosenLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.xl,
        childAspectRatio: 0.72,
      ),
      itemCount: suggested.length,
      itemBuilder: (context, i) {
        final option = suggested[i];
        final selected = chosenLabels.contains(option.label);
        return PhotoTile(
          option: option,
          selected: selected,
          onTap: () {
            final controller = ref.read(onboardingFlowProvider.notifier);
            if (selected) {
              controller.removeCustomInterest(option.label);
            } else {
              controller.addCustomInterest(option.label);
            }
          },
        );
      },
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: colors.surface,
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.chevron_left, size: AppSizes.iconLg),
          color: colors.textPrimary,
          tooltip: 'Back',
        ),
      ),
    );
  }
}
