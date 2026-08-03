import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/wishtick_error_text.dart';
import '../domain/onboarding_options.dart';
import 'onboarding_flow_controller.dart';
import 'widgets/onboarding_step_scaffold.dart';
import 'widgets/photo_tile_grid.dart';
import 'widgets/selection_footer.dart';

/// Step 2 — "Tell us what you love" (Figma `36:839`).
///
/// Twelve photo tiles, up to [OnboardingCaps.interestCategories] selected.
/// Continue walks the detail screen of each chosen category in order; SKIP
/// jumps straight to colours saving nothing.
class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(onboardingFlowProvider.notifier).ensureOptions(),
    );
  }

  Future<bool> _onContinue() async => true;

  void _afterContinue() {
    if (!mounted) return;
    final flow = ref.read(onboardingFlowProvider);
    // First detail screen of the queue; each detail advances to the next.
    context.push(AppRoutes.onboardingInterestDetail(flow.detailQueue.first));
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(onboardingFlowProvider);
    final options = flow.options;
    final selected = flow.selectedCategories;

    return OnboardingStepScaffold(
      step: 2,
      headline: 'Tell us what you love',
      subtitle:
          "Pick a few - we'll surprise you with gifts that feel personal.",
      onBack: () => context.go(AppRoutes.onboarding),
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
        (final OnboardingOptions loaded, _) => PhotoTileGrid(
          options: loaded.interestCategories,
          selectedKeys: selected.toSet(),
          onToggle: (key) =>
              ref.read(onboardingFlowProvider.notifier).toggleCategory(key),
        ),
      },
      footer: SelectionFooter(
        summary: selected.isEmpty
            ? null
            : '(${selected.length}/${OnboardingCaps.interestCategories})',
        onClearAll: selected.isEmpty
            ? null
            : () => ref.read(onboardingFlowProvider.notifier).clearCategories(),
        onContinue: selected.isEmpty ? null : _onContinue,
        onContinueSucceeded: _afterContinue,
        onSkip: () => context.go(AppRoutes.onboardingColors),
        error: flow.error,
      ),
    );
  }
}
