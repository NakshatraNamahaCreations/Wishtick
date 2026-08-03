import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/mobile_number_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/onboarding/presentation/all_set_screen.dart';
import '../../features/onboarding/presentation/avatar_picker_screen.dart';
import '../../features/onboarding/presentation/category_detail_screen.dart';
import '../../features/onboarding/presentation/colors_screen.dart';
import '../../features/onboarding/presentation/create_profile_screen.dart';
import '../../features/onboarding/presentation/important_dates_screen.dart';
import '../../features/onboarding/presentation/interests_screen.dart';
import '../../features/onboarding/presentation/size_fit_screen.dart';
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
  final refresh = ValueNotifier<(SessionStatus, bool)>((
    SessionStatus.unknown,
    false,
  ));
  ref.listen(
    sessionProvider,
    (_, next) => refresh.value = (next.status, next.onboardingCompleted),
  );
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
      final inOnboarding = location.startsWith(AppRoutes.onboarding);

      // Hold on the splash until the stored session has been resolved.
      if (!session.isResolved) return onSplash ? null : AppRoutes.splash;

      if (!session.isAuthenticated) {
        return inAuthFlow ? null : AppRoutes.welcome;
      }

      // Signed in but the required profile step is unfinished — onboarding is
      // the only place to be.
      if (!session.onboardingCompleted) {
        return inOnboarding ? null : AppRoutes.onboarding;
      }

      // Fully set up: the splash, the auth flow and onboarding are dead ends.
      if (onSplash || inAuthFlow || inOnboarding) return AppRoutes.home;
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
            path: 'mobile',
            builder: (context, state) => const MobileNumberScreen(),
          ),
          GoRoute(path: 'otp', builder: (context, state) => const OtpScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const CreateProfileScreen(),
        routes: [
          GoRoute(
            path: 'avatar',
            builder: (context, state) => const AvatarPickerScreen(),
          ),
          GoRoute(
            path: 'interests',
            builder: (context, state) => const InterestsScreen(),
            routes: [
              GoRoute(
                path: ':category',
                builder: (context, state) => CategoryDetailScreen(
                  categoryKey: state.pathParameters['category']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'colors',
            builder: (context, state) => const ColorsScreen(),
          ),
          GoRoute(
            path: 'sizes',
            builder: (context, state) => const SizeFitScreen(),
          ),
          GoRoute(
            path: 'dates',
            builder: (context, state) => const ImportantDatesScreen(),
          ),
          GoRoute(
            path: 'done',
            builder: (context, state) => const AllSetScreen(),
          ),
        ],
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
