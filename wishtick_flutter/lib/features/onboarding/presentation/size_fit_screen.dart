import 'dart:math' as math;

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
                // One image for every size — XXS through 3XL all wear the
                // same hanger — so the builder ignores which option it was
                // asked for.
                iconFor: (_, selected) => TileIcons.fixed('clothing', selected),
                scaleIconWithRank: true,
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
                iconFor: (_, selected) => TileIcons.fixed('shoes', selected),
                // Tiles show just the number; the system is in the toggle.
                labelOf: (o) => o.label.split(' ').last,
                scaleIconWithRank: true,
                onTap: controller.setShoeSize,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              _SectionHeader(number: '03', title: 'Fit Preference'),
              const SizedBox(height: AppSpacing.lg),
              _TileWrap(
                options: loaded.fitPreferences,
                selectedKey: flow.fitPreference,
                // Each fit has its own drawn silhouette, unlike the size
                // grids above.
                iconFor: (option, selected) =>
                    TileIcons.fit(option.key, selected),
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

/// Resolves the brand PNGs for the three tile sections.
///
/// None of these are tinted at runtime. Each is exported as two flat,
/// pre-coloured PNGs — brand plum for the unselected tile, white for the
/// selected one — so this just chooses between the two files rather than
/// applying a colour filter. `daimond.png` and `others.png` elsewhere in the
/// app are the opposite case (alpha-only, tinted via `IconTheme`); these are
/// not that, because the design specifies an exact selected/unselected pair
/// per icon rather than "whatever the theme says".
abstract final class TileIcons {
  /// Clothing and Shoes: one drawing stands for the whole section, so every
  /// option — XXS through 3XL, UK 3 through 13 — shows the same image.
  static Widget fixed(String name, bool selected) =>
      Image.asset(_path(name, selected), fit: BoxFit.contain);

  /// Fit Preference: a distinct silhouette per option, keyed by the taxonomy
  /// key the backend sends (`slim`, `regular`, `relaxed`, `oversized`).
  ///
  /// The asset filenames were handed over with inconsistent capitalisation
  /// (`Slim.png`, `regular.png`, `Relaxed.png`, `Oversized.png`) — this map
  /// is what absorbs that, so callers key everything off the lowercase
  /// taxonomy key instead of guessing a filename's case.
  static Widget fit(String key, bool selected) {
    final name = _fitAssetNames[key];
    if (name == null) {
      // The options list comes from a live API; a fit the client adds
      // tomorrow arrives with no matching asset yet. Falling back to the
      // clothing glyph keeps the tile legible instead of throwing mid-build.
      return fixed('clothing', selected);
    }
    return Image.asset(_path(name, selected), fit: BoxFit.contain);
  }

  static const _fitAssetNames = {
    'slim': 'Slim',
    'regular': 'regular',
    'relaxed': 'Relaxed',
    'oversized': 'Oversized',
  };

  static String _path(String name, bool selected) =>
      'assets/icons/$name${selected ? '_w' : ''}.png';
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
        color: colors.toggleTrack,
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
    required this.iconFor,
    required this.onTap,
    this.labelOf,
    this.large = false,
    this.scaleIconWithRank = false,
  });

  final List<TaxonomyOption> options;
  final String? selectedKey;

  /// Builds the tile's artwork for one option, already in its final
  /// selected/unselected colour — see [TileIcons].
  final Widget Function(TaxonomyOption option, bool selected) iconFor;

  final ValueChanged<String> onTap;
  final String Function(TaxonomyOption)? labelOf;
  final bool large;

  /// Clothing and Shoes draw the *same* glyph in every tile — there is no
  /// per-size artwork — so XXS and 3XL were indistinguishable at a glance
  /// beyond the label. With this on, the icon itself grows from
  /// [_minRankScale] at the first option to full size at the last, in list
  /// order, so the run of tiles reads as a size ramp the way a real size
  /// chart does. Fit Preference leaves this off: its four options are
  /// already four different drawings, so scaling them too would compound
  /// the cue rather than add one.
  final bool scaleIconWithRank;

  /// The icon is sized as a fraction of the tile rather than a fixed
  /// constant, so the fit-preference tiles (`large`) — which carry the only
  /// per-option artwork here and are the ones the eye lands on first — read
  /// as bigger than the repeated clothing/shoe glyph, and either would shrink
  /// in step with a smaller tile rather than overflowing or floating loose
  /// in too much empty space.
  static const _iconFraction = 0.5;

  /// Smallest rung of the size ramp, as a fraction of the full icon size.
  /// Low enough to read as clearly smaller than 3XL; not so low that XXS's
  /// artwork gets hard to identify at a glance.
  static const _minRankScale = 0.55;

  /// Where option [index] of [count] sits on the ramp, 0 at the first tile,
  /// 1 at the last. A single option has nothing to ramp between.
  static double _rank(int index, int count) =>
      count <= 1 ? 1 : index / (count - 1);

  /// The icon box for option [index] — full [iconSize] unless
  /// [scaleIconWithRank] puts it somewhere on the size ramp.
  double _iconSizeFor(int index, double iconSize) {
    if (!scaleIconWithRank) return iconSize;
    final scale =
        _minRankScale + (1 - _minRankScale) * _rank(index, options.length);
    return iconSize * scale;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final width = large ? 84.0 : 68.0;
    final height = large ? 78.0 : 68.0;
    final iconSize = math.min(width, height) * _iconFraction;

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: [
        for (final (index, option) in options.indexed)
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
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: option.key == selectedKey
                          ? colors.primary
                          : colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: _iconSizeFor(index, iconSize),
                          height: _iconSizeFor(index, iconSize),
                          child: iconFor(option, option.key == selectedKey),
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
