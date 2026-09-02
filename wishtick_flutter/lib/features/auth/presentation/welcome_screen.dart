import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';

/// One page of the welcome carousel.
///
/// The artwork is the whole screen — headline, body, logo and a plum call to
/// action are all drawn into the image. Nothing here re-states them, because
/// anything this file drew would land on top of the picture that already says
/// it.
class WelcomeSlide {
  const WelcomeSlide({
    required this.asset,
    required this.action,
    required this.button,
    required this.figmaNodeId,
  });

  final String asset;

  /// What the button drawn in the artwork says, used as the tap target's
  /// accessible name — the words are pixels, so a screen reader has no other
  /// way to reach them.
  final String action;

  /// Where that button sits, as fractions of the image.
  ///
  /// Per slide because the four designs place it at four different heights,
  /// and measured off the shipped asset rather than eyeballed — see
  /// `welcome_screen_test.dart`, which re-measures the bundled images and
  /// fails if a re-export moves a button out from under its hit area.
  final Rect button;

  final String figmaNodeId;
}

/// Welcome carousel — Figma `7:81`, `280:33`, `280:56`, `280:102`.
///
/// Four full-bleed composed screens. Swiping moves between them; tapping the
/// button drawn at the bottom of each advances, and on the last one enters the
/// sign-in flow.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const slides = <WelcomeSlide>[
    WelcomeSlide(
      asset: 'assets/onboarding_carousel/1.webp',
      action: 'Create Wishlist',
      button: Rect.fromLTRB(0.1603, 0.8625, 0.8275, 0.9271),
      figmaNodeId: '7:81',
    ),
    WelcomeSlide(
      asset: 'assets/onboarding_carousel/2.webp',
      action: 'Share Wishlist',
      button: Rect.fromLTRB(0.0952, 0.8765, 0.9063, 0.9408),
      figmaNodeId: '280:33',
    ),
    WelcomeSlide(
      asset: 'assets/onboarding_carousel/3.webp',
      action: 'Wish Fulfilled',
      button: Rect.fromLTRB(0.0947, 0.9054, 0.8910, 0.9646),
      figmaNodeId: '280:56',
    ),
    WelcomeSlide(
      asset: 'assets/onboarding_carousel/4.webp',
      action: 'Start Wishticking',
      button: Rect.fromLTRB(0.0852, 0.8890, 0.8820, 0.9530),
      figmaNodeId: '280:102',
    ),
  ];

  /// What the artwork was drawn at — 9:16.
  ///
  /// Every phone is taller than this, and the slides are painted with
  /// [BoxFit.cover], so the sides are what get trimmed: 11% off each edge at
  /// 20.5:9, 12% at 21:9. Redrawing the four slides on a taller canvas — 9:18
  /// halves it, 9:21 removes it on phones — with nothing important inside the
  /// outer margin is what fixes that, and this constant plus the four button
  /// rects above must be re-measured against the new export when it lands.
  static const artworkAspectRatio = 1890 / 3360;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == WelcomeScreen.slides.length - 1;

  @override
  void initState() {
    super.initState();
    // Decoded ahead of the swipe. Each image is most of a megabyte, and
    // decoding one at the moment the page turns shows a blank frame on the way
    // in — on the first screen of the app, which is the worst place for it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _precache());
  }

  void _precache() {
    for (final slide in WelcomeScreen.slides) {
      if (!mounted) return;
      precacheImage(AssetImage(slide.asset), context);
    }
  }

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark icons: the artwork is covered rather than letterboxed, so the
      // status bar sits over the design itself — and all four are light at the
      // top. They read against the white canvas behind too, for the frame
      // before a slide finishes decoding.
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.colors.artworkCanvas,
        // Not wrapped in SafeArea: these are full-bleed designs and the top of
        // each is deliberately empty behind the status bar.
        body: PageView.builder(
          controller: _controller,
          itemCount: WelcomeScreen.slides.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (context, index) =>
              _Slide(slide: WelcomeScreen.slides[index], onTap: _onContinue),
        ),
      ),
    );
  }
}

/// One full-bleed artwork with a hit area over the button drawn into it.
class _Slide extends StatelessWidget {
  const _Slide({required this.slide, required this.onTap});

  final WelcomeSlide slide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The drawn button's position is a fraction of the *image*, so it has
        // to be worked out against where the image actually landed rather than
        // against the box it was given.
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final painted = _paintedRect(box, WelcomeScreen.artworkAspectRatio);
        final button = Rect.fromLTRB(
          painted.left + slide.button.left * painted.width,
          painted.top + slide.button.top * painted.height,
          painted.left + slide.button.right * painted.width,
          painted.top + slide.button.bottom * painted.height,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                slide.asset,
                // `cover`: the artwork fills the screen edge to edge on every
                // device, at the cost of trimming whichever axis has to give.
                //
                // The art is drawn 9:16 and phones are taller than that, so
                // what gets trimmed on a phone is the *sides* — 11% off each
                // edge at 20.5:9. The headline runs to the left edge and the
                // logo to the right, so both lose a little; the drawn button
                // loses its rounded ends on the tallest screens. Redrawing the
                // slides on a taller canvas with the artwork kept clear of the
                // outer margin is what removes that cost — see the note on
                // [WelcomeScreen.artworkAspectRatio].
                fit: BoxFit.cover,
                // Excluded from semantics because the hit area below carries
                // the only name a reader can act on. A second, unlabelled
                // image node would just be noise before it.
                excludeFromSemantics: true,
              ),
            ),
            Positioned.fromRect(
              rect: button,
              child: Semantics(
                button: true,
                label: slide.action,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  // Deliberately draws nothing: the button is already in the
                  // picture. Painting one here would put a button inside a
                  // button.
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Where a [BoxFit.cover] image actually lands relative to [box].
  ///
  /// Deliberately *larger* than the box and centred, so the returned rect can
  /// start at a negative offset. That is the whole difference from `contain`,
  /// and it is why the button's fractions have to be resolved against this
  /// rather than against the box: under cover the image no longer starts at
  /// the box's origin, and a button placed as a fraction of the box would
  /// drift further off the drawn one the taller the screen gets.
  static Rect _paintedRect(Size box, double aspectRatio) {
    final boxAspect = box.width / box.height;
    if (boxAspect > aspectRatio) {
      // Box is wider than the art: match the width, overflow above and below.
      final height = box.width / aspectRatio;
      return Rect.fromLTWH(0, (box.height - height) / 2, box.width, height);
    }
    // Taller than the art — every modern phone: match the height, overflow
    // left and right.
    final width = box.height * aspectRatio;
    return Rect.fromLTWH((box.width - width) / 2, 0, width, box.height);
  }
}
