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
  });

  /// Serif display headline, line-broken exactly as the design does.
  final String headline;
  final String body;
  final String figmaNodeId;
}

/// Welcome carousel — Figma `7:81`, `280:33`, `280:56`, `280:102`.
///
/// One shared piece of artwork fills the top of the screen; below it a serif
/// headline, body copy, four page dots and a full-width plum pill button. The
/// last slide's button reads "Get Started" instead of "Continue".
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  /// The artwork is identical on all four frames, so it is one asset.
  static const heroAsset = 'assets/images/welcome_hero.png';

  static const slides = <WelcomeSlide>[
    WelcomeSlide(
      headline: 'Make Every\nWish Count!',
      body:
          'Create your personal wishlist and help your loved ones choose gifts '
          "you'll truly cherish.",
      figmaNodeId: '7:81',
    ),
    WelcomeSlide(
      // "Ocassion" is the design's spelling — see the note in sprints.md.
      headline: 'Every Ocassion\nMade Special!',
      body:
          'From birthdays and anniversaries to festivals and special '
          'milestones, celebrate every moment with love.',
      figmaNodeId: '280:33',
    ),
    WelcomeSlide(
      headline: 'Great Gifts\nBring Us Together!',
      body:
          'Chip in with friends and family to surprise someone with a gift '
          "they'll never forget.",
      figmaNodeId: '280:56',
    ),
    WelcomeSlide(
      headline: 'The Little Moments\nMatter Most !',
      body:
          "Whether it's a simple thank you, a surprise, or just because "
          "you'll always find a reason to make someone smile.",
      figmaNodeId: '280:102',
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
      context.go(AppRoutes.mobileNumber);
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
          // The artwork sits behind the status bar, as designed.
          Expanded(
            flex: 526,
            child: SizedBox(
              width: double.infinity,
              child: Image.asset(
                WelcomeScreen.heroAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Expanded(
            flex: 326,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: WelcomeScreen.slides.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) =>
                          _SlideCopy(slide: WelcomeScreen.slides[i]),
                    ),
                  ),
                  _Dots(count: WelcomeScreen.slides.length, index: _index),
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      0,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                    ),
                    child: ElevatedButton(
                      onPressed: _onContinue,
                      child: Text(_isLast ? 'Get Started' : 'Continue'),
                    ),
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

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({required this.slide});

  final WelcomeSlide slide;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Scrollable so a short device or a large text-scale setting shrinks the
    // copy area gracefully instead of overflowing it.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            slide.headline,
            textAlign: TextAlign.center,
            style: AppTypography.displayMedium.copyWith(color: colors.primary),
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
    );
  }
}

/// Four equal dots; the active one is filled with the brand plum.
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
