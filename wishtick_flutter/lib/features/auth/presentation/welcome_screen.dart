import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light icons, to read against the dark scrim below rather than
      // against the photo itself — the app-wide default (dark icons, tuned
      // for the beige page every other screen sits on) would nearly
      // disappear here.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.background,
        body: Column(
          children: [
            // Not wrapped in SafeArea: the image's box height is tuned to
            // Figma's own crop (526/852 of the *full* screen), and shrinking
            // it — even by a status-bar's worth — needs less of the photo
            // cropped away, exposing a flat band near the subject's lap that
            // the original crop was hiding. A scrim over the top of the
            // image, not a shorter image, is what keeps the status bar
            // legible without touching that crop.
            Expanded(
              flex: 526,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    WelcomeScreen.heroAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: MediaQuery.paddingOf(context).top,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.overlay,
                            colors.overlay.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Fades the photo into the page colour instead of ending on
                  // a hard edge — the design fades it into white over the
                  // last ~12% of the image; this is the same fade, into
                  // `colors.background` since that's this screen's actual
                  // page colour, not Figma's.
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.12,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors.background.withValues(alpha: 0),
                              colors.background,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
                        // The dots live inside each page rather than as a
                        // sibling below the PageView. All four pages read
                        // the same `_index`, so whichever page is showing
                        // draws the identical row — the dots read as one
                        // fixed indicator, not four swiping in and out.
                        //
                        // The reason: the headline+body are vertically
                        // centred *within the page*, and a PageView page
                        // fills all the space this Expanded is given. A
                        // dots row placed after the PageView instead sits
                        // wherever that leftover space happens to end —
                        // mostly empty flex space, not a fixed gap — which
                        // is what made it read as too far from the text
                        // above it. Grouping the dots with the text they
                        // belong to means both centre together.
                        itemBuilder: (context, i) => _SlideCopy(
                          slide: WelcomeScreen.slides[i],
                          dots: _Dots(
                            count: WelcomeScreen.slides.length,
                            index: _index,
                          ),
                        ),
                      ),
                    ),
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
      ),
    );
  }
}

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({required this.slide, required this.dots});

  final WelcomeSlide slide;

  /// Rendered right under the body copy — see the note where this is built.
  final Widget dots;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Scrollable so a short device or a large text-scale setting shrinks the
    // copy area gracefully instead of overflowing it.
    //
    // A bare Column inside a SingleChildScrollView cannot be bottom-aligned:
    // the scroll view hands its child *unbounded* height, so the Column
    // always shrink-wraps to its content and starts at the top — an `end`
    // mainAxisAlignment is a no-op with nothing to distribute space into.
    // LayoutBuilder recovers the real box height so ConstrainedBox can give
    // the Column something to align within, while `minHeight` (not a fixed
    // height) still lets it grow past that box and scroll if a long
    // translation or a large text-scale setting ever needs more room.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            // Bottom-anchored, not centred: the dots need to sit right above
            // the Continue button below this PageView, with whatever slack
            // the device's height leaves going above the headline instead —
            // matching the design, where headline/body/dots sit as one tight
            // group with only a small gap to the button.
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                slide.headline,
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
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
              const SizedBox(height: AppSpacing.md),
              dots,
            ],
          ),
        ),
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
