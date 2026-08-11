import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/hex_color.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/sparkle_icon.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/onboarding_options.dart';
import 'onboarding_flow_controller.dart';
import 'widgets/onboarding_step_scaffold.dart';
import 'widgets/selection_footer.dart';

/// Step 3 — "What's your favourite color?" (Figma `39:1061` v2).
///
/// Eight grouped swatch cards; up to [OnboardingCaps.colors] picks. A gold
/// note card explains what the colours are used for. Selected = ring + plum
/// check badge.
class ColorsScreen extends ConsumerStatefulWidget {
  const ColorsScreen({super.key});

  @override
  ConsumerState<ColorsScreen> createState() => _ColorsScreenState();
}

class _ColorsScreenState extends ConsumerState<ColorsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(onboardingFlowProvider.notifier).ensureOptions(),
    );
  }

  Future<bool> _onContinue() =>
      ref.read(onboardingFlowProvider.notifier).saveColors();

  void _afterContinue() {
    if (mounted) context.go(AppRoutes.onboardingSizes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final flow = ref.watch(onboardingFlowProvider);
    final options = flow.options;
    final selected = flow.selectedColors;

    return OnboardingStepScaffold(
      step: 3,
      headline: "What's your favourite color?",
      subtitle: 'Choose a color you love. You can change it anytime.',
      onBack: () => context.go(AppRoutes.onboardingInterests),
      body: switch ((options, flow.optionsError)) {
        (null, null) => const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
        (null, final String message) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              WishtickErrorText(message),
              TextButton(
                onPressed: () =>
                    ref.read(onboardingFlowProvider.notifier).retryOptions(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        (final OnboardingOptions loaded, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              for (final group in loaded.colorGroups) ...[
                _ColorGroupCard(
                  group: group,
                  selectedKeys: selected.toSet(),
                  onToggle: (key) => ref
                      .read(onboardingFlowProvider.notifier)
                      .toggleColor(key),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.celebrationSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SparkleIcon(
                      size: AppSizes.iconMd,
                      color: colors.celebration,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        // Verbatim from the design, grammar and all.
                        'This colors will be used to personalize you '
                        'wishtick experience',
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      },
      footer: SelectionFooter(
        summary: selected.isEmpty
            ? null
            : '(${selected.length}/${OnboardingCaps.colors})',
        onClearAll: selected.isEmpty
            ? null
            : () => ref.read(onboardingFlowProvider.notifier).clearColors(),
        onContinue: selected.isEmpty ? null : _onContinue,
        onContinueSucceeded: _afterContinue,
        onSkip: () => context.go(AppRoutes.onboardingSizes),
        busy: flow.busy,
        error: flow.error,
      ),
    );
  }
}

/// One white card per colour family: emoji-free title row per the design,
/// then five labelled swatch circles.
class _ColorGroupCard extends StatelessWidget {
  const _ColorGroupCard({
    required this.group,
    required this.selectedKeys,
    required this.onToggle,
  });

  final ColorGroup group;
  final Set<String> selectedKeys;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.label,
            style: context.text.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final swatch in group.colors)
                Expanded(
                  child: _Swatch(
                    option: swatch,
                    selected: selectedKeys.contains(swatch.key),
                    onTap: () => onToggle(swatch.key),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final TaxonomyOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = parseHexColor(
      option.meta?['hex'] ?? '',
      fallback: colors.surfaceAlt,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    // A hairline keeps white/pale swatches visible on the card.
                    border: Border.all(
                      color: selected ? colors.primary : colors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                        border: Border.all(color: colors.surface),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 12,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              option.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
