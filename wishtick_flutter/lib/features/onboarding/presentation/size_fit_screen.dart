import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/onboarding_options.dart';
import 'onboarding_flow_controller.dart';
import 'widgets/onboarding_step_scaffold.dart';
import 'widgets/selection_footer.dart';

/// Step 4 — "Help Us Pick the Perfect Fit" (Figma `51:42`).
///
/// Numbered sections: 01 Clothing (single-select tiles), 02 Shoes with a
/// UK/US/EU toggle, 03 Fit Preference. The footer summary describes the picks
/// ("Clothing: XS, Shoes: UK 9, Fit: Regular") rather than a count.
class SizeFitScreen extends ConsumerStatefulWidget {
  const SizeFitScreen({super.key});

  @override
  ConsumerState<SizeFitScreen> createState() => _SizeFitScreenState();
}

class _SizeFitScreenState extends ConsumerState<SizeFitScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(onboardingFlowProvider.notifier).ensureOptions(),
    );
  }

  Future<bool> _onContinue() =>
      ref.read(onboardingFlowProvider.notifier).saveSizes();

  void _afterContinue() {
    if (mounted) context.go(AppRoutes.onboardingDates);
  }

  String? _summary(OnboardingFlowState flow) {
    final options = flow.options;
    if (options == null || !flow.hasSizeSelection) return null;
    String label(List<TaxonomyOption> from, String? key) =>
        from.where((o) => o.key == key).firstOrNull?.label ?? '';
    final parts = [
      if (flow.clothingSize != null)
        'Clothing: ${label(options.clothingSizes, flow.clothingSize)}',
      if (flow.shoeSize != null)
        'Shoes: ${label(options.shoeSizes, flow.shoeSize)}',
      if (flow.fitPreference != null)
        'Fit: ${label(options.fitPreferences, flow.fitPreference)}',
    ];
    return '(${parts.join(', ')})';
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(onboardingFlowProvider);
    final options = flow.options;
    final controller = ref.read(onboardingFlowProvider.notifier);

    return OnboardingStepScaffold(
      step: 4,
      headline: 'Help Us Pick the\nPerfect Fit',
      subtitle:
          'Tell us your clothing and shoe sizes so friends and family can '
          'choose gifts that fit just right.',
      onBack: () => context.go(AppRoutes.onboardingColors),
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
                onPressed: controller.retryOptions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        (final OnboardingOptions loaded, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(number: '01', title: 'Clothing'),
              const SizedBox(height: AppSpacing.lg),
              _TileWrap(
                options: loaded.clothingSizes
                    .where((o) => o.key != 'prefer_not_to_say')
                    .toList(),
                selectedKey: flow.clothingSize,
                icon: Icons.checkroom,
                onTap: controller.setClothingSize,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Row(
                children: [
                  _SectionHeader(number: '02', title: 'Shoes'),
                  const Spacer(),
                  _SystemToggle(
                    system: flow.shoeSystem,
                    onChanged: controller.setShoeSystem,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _TileWrap(
                options: loaded.shoeSizesFor(flow.shoeSystem),
                selectedKey: flow.shoeSize,
                icon: Icons.ice_skating_outlined,
                // Tiles show just the number; the system is in the toggle.
                labelOf: (o) => o.label.split(' ').last,
                onTap: controller.setShoeSize,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _SectionHeader(number: '03', title: 'Fit Preference'),
              const SizedBox(height: AppSpacing.lg),
              _TileWrap(
                options: loaded.fitPreferences,
                selectedKey: flow.fitPreference,
                icon: Icons.checkroom,
                large: true,
                onTap: controller.setFitPreference,
              ),
            ],
          ),
        ),
      },
      footer: SelectionFooter(
        summary: _summary(flow),
        onClearAll: flow.hasSizeSelection ? controller.clearSizes : null,
        onContinue: flow.hasSizeSelection ? _onContinue : null,
        onContinueSucceeded: _afterContinue,
        onSkip: () => context.go(AppRoutes.onboardingDates),
        busy: flow.busy,
        error: flow.error,
      ),
    );
  }
}

/// "01  Clothing" — pink numbered chip beside a bold title.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colors.accentSubtle,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(
            number,
            style: context.text.labelSmall?.copyWith(
              color: colors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: context.text.headlineSmall?.copyWith(
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// The UK / US / EU pill toggle.
class _SystemToggle extends StatelessWidget {
  const _SystemToggle({required this.system, required this.onChanged});

  final String system;
  final ValueChanged<String> onChanged;

  static const _systems = ['uk', 'us', 'eu'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in _systems)
            GestureDetector(
              onTap: () => onChanged(s),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: s == system ? colors.primary : null,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  s.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: s == system ? colors.onPrimary : colors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A wrap of white square tiles with an icon over a label; selected = plum
/// fill, inverted content, check badge.
class _TileWrap extends StatelessWidget {
  const _TileWrap({
    required this.options,
    required this.selectedKey,
    required this.icon,
    required this.onTap,
    this.labelOf,
    this.large = false,
  });

  final List<TaxonomyOption> options;
  final String? selectedKey;
  final IconData icon;
  final ValueChanged<String> onTap;
  final String Function(TaxonomyOption)? labelOf;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = large ? 78.0 : 68.0;

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: [
        for (final option in options)
          Semantics(
            button: true,
            selected: option.key == selectedKey,
            label: option.label,
            child: GestureDetector(
              onTap: () => onTap(option.key),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: large ? 84 : 68,
                    height: size,
                    decoration: BoxDecoration(
                      color: option.key == selectedKey
                          ? colors.primary
                          : colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: AppSizes.iconLg,
                          color: option.key == selectedKey
                              ? colors.onPrimary
                              : colors.primary,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          labelOf?.call(option) ?? option.label,
                          textAlign: TextAlign.center,
                          style: context.text.labelSmall?.copyWith(
                            color: option.key == selectedKey
                                ? colors.onPrimary
                                : colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (option.key == selectedKey)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surface,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 18,
                          color: colors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
