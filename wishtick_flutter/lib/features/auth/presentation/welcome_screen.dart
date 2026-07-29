import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_extensions.dart';

/// One page of the welcome carousel.
class WelcomeSlide {
  const WelcomeSlide({
    required this.headline,
    required this.body,
    required this.figmaNodeId,
    this.imageAsset,
  });

  /// Serif display headline, broken across lines exactly as the design does.
  final String headline;
  final String body;

  /// Full-bleed artwork above the copy. Null until the asset is exported from
  /// Figma, in which case a themed placeholder is drawn instead.
  final String? imageAsset;

  final String figmaNodeId;
}

/// Welcome carousel — Figma `7:81` and its sibling frames.
///
/// Artwork fills the top of the screen, then a serif headline, body copy, page
/// dots and a full-width plum pill button.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  /// Only the first slide's copy is transcribed from Figma so far — the Figma
  /// MCP tool-call quota ran out before the remaining frames could be opened.
  /// Fill these in from `251:580`, `280:33`, `280:56` and `280:102`; the
  /// carousel itself needs no changes.
  static const slides = <WelcomeSlide>[
    WelcomeSlide(
      headline: 'Make Every\nWish Count!',
      body:
          'Create your personal wishlist and help your loved ones choose gifts '
          "you'll truly cherish.",
      figmaNodeId: '7:81',
    ),
  ];

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == WelcomeScreen.slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_isLast) {
      context.go(AppRoutes.createAccount);
      return;
    }
    _controller.nextPage(duration: AppDurations.normal, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: WelcomeScreen.slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) =>
                  _Slide(slide: WelcomeScreen.slides[i]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                0,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (WelcomeScreen.slides.length > 1) ...[
                    _Dots(count: WelcomeScreen.slides.length, index: _index),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                  ElevatedButton(
                    onPressed: _onContinue,
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide});

  final WelcomeSlide slide;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Expanded(
          flex: 6,
          child: SizedBox(
            width: double.infinity,
            child: slide.imageAsset == null
                ? _ArtworkPlaceholder(figmaNodeId: slide.figmaNodeId)
                : Image.asset(slide.imageAsset!, fit: BoxFit.cover),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slide.headline,
                  textAlign: TextAlign.center,
                  style: AppTypography.displayLarge.copyWith(
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge?.copyWith(
                    color: colors.textSecondary,
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

/// Stands in for the exported Figma artwork so the layout is honest about its
/// proportions before the assets land.
class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({required this.figmaNodeId});

  final String figmaNodeId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ColoredBox(
      color: colors.accentSubtle,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 40, color: colors.accent),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Artwork $figmaNodeId',
              style: context.text.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppDurations.fast,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: i == index ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? colors.primary : colors.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
