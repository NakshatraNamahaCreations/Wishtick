import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/settings/presentation/appearance_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../widgets/sprint_placeholder.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// The app's route table.
///
/// Later sprints replace each [SprintPlaceholder] with the real screen; the
/// placeholders carry the Figma node ID so the design is one lookup away.
final routerProvider = Provider<GoRouter>((ref) {
  // go_router only re-evaluates `redirect` when this notifier fires, so the
  // session status is what drives navigation.
  final refresh = ValueNotifier<SessionStatus>(SessionStatus.unknown);
  ref.listen(sessionProvider, (_, next) => refresh.value = next.status);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final onSplash = location == AppRoutes.splash;
      final inAuthFlow = location.startsWith(AppRoutes.welcome);

      // Hold on the splash until the stored session has been resolved.
      if (!session.isResolved) return onSplash ? null : AppRoutes.splash;

      if (!session.isAuthenticated) {
        return inAuthFlow ? null : AppRoutes.welcome;
      }

      // Signed in: the splash and the auth flow are both dead ends now.
      if (onSplash || inAuthFlow) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: 'create-account',
            builder: (context, state) => const SprintPlaceholder(
              title: 'Create account',
              sprint: 'Sprint 1 — Auth',
              figmaNodeId: '31:608',
            ),
          ),
          GoRoute(
            path: 'mobile',
            builder: (context, state) => const SprintPlaceholder(
              title: 'Mobile number',
              sprint: 'Sprint 1 — Auth',
              figmaNodeId: '17:329',
            ),
          ),
          GoRoute(
            path: 'otp',
            builder: (context, state) => const SprintPlaceholder(
              title: 'Verification',
              sprint: 'Sprint 1 — Auth',
              figmaNodeId: '17:530',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const SprintPlaceholder(
          title: 'Onboarding',
          sprint: 'Sprint 2 — Personalization',
          figmaNodeId: '33:751',
        ),
      ),
      GoRoute(
        path: AppRoutes.appearance,
        builder: (context, state) => const AppearanceScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const SprintPlaceholder(
                  title: 'Home',
                  sprint: 'Sprint 4 — Home & discovery',
                  figmaNodeId: '51:11',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wishlist,
                builder: (context, state) => const SprintPlaceholder(
                  title: 'Wishlist',
                  sprint: 'Sprint 3 — Wishlist core',
                  figmaNodeId: '280:428',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.memories,
                builder: (context, state) => const SprintPlaceholder(
                  title: 'Memories',
                  sprint: 'Sprint 8 — Memories',
                  figmaNodeId: '2032:460',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const SprintPlaceholder(
                  title: 'Profile',
                  sprint: 'Sprint 9 — Notifications & Profile',
                  figmaNodeId: '64:158',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
