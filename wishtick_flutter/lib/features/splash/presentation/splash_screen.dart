import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../auth/presentation/session_controller.dart';

/// Splash — a single full-bleed GIF (`assets/images/splash_screen.gif`),
/// which already carries the mark, wordmark, tagline and progress bar as
/// baked-in frames, so there is no separate widget-level animation to build
/// or theme here.
///
/// The stored session is resolved after [AppDurations.splash] (4.5s), not
/// immediately, so the brand moment gets its screen time before the router's
/// redirect takes over as soon as the session lands.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const asset = 'assets/images/splash_screen.gif';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(AppDurations.splash, _onDone);
  }

  void _onDone() {
    if (!mounted) return;
    // Resolving the session flips it off `unknown`, which fires the router's
    // refreshListenable and redirects to home or the welcome flow.
    unawaited(ref.read(sessionProvider.notifier).restore());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The GIF's own backdrop is dark throughout, so the status-bar icons
      // must be light regardless of the active theme.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // Matches the GIF's own darkest frame, so there is no flash of the
        // page theme's background before the first frame paints.
        backgroundColor: context.colors.splashBackground,
        body: SizedBox.expand(
          child: Image.asset(SplashScreen.asset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
