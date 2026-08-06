import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/mobile_number_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/events/presentation/invite_screen.dart';
import '../../features/gifting/presentation/gift_details_screen.dart';
import '../../features/gifting/presentation/gift_item_screen.dart';
import '../../features/gifting/presentation/order_confirmed_screen.dart';
import '../../features/gifting/presentation/order_controller.dart';
import '../../features/gifting/presentation/order_delivered_screen.dart';
import '../../features/gifting/presentation/track_order_screen.dart';
import '../../features/home/presentation/delivery_location_screen.dart';
import '../../features/home/presentation/home_screen.dart';
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
import '../../features/wishlist/domain/product.dart';
import '../../features/wishlist/domain/wishlist.dart';
import '../../features/wishlist/presentation/create_wishlist_screen.dart';
import '../../features/wishlist/presentation/product_detail_screen.dart';
import '../../features/wishlist/presentation/public_wishlist_screen.dart';
import '../../features/wishlist/presentation/wishlist_detail_screen.dart';
import '../../features/wishlist/presentation/wishlist_item_detail_screen.dart';
import '../../features/wishlist/presentation/wishlist_tab_screen.dart';
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
      // A shared wishlist or an event invite is a public link: someone sent it
      // to a friend who may have no account. Sending them to sign-in would
      // break the share.
      final isPublicLink =
          location.startsWith('/w/') || location.startsWith('/i/');

      if (isPublicLink) return null;

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
      GoRoute(
        path: AppRoutes.deliveryLocation,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DeliveryLocationScreen(),
      ),
      GoRoute(
        // A share link, so it must resolve without a session — the redirect
        // below lets it through for exactly that reason.
        path: '/w/:slug',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PublicWishlistScreen(
          slug: state.pathParameters['slug']!,
          passcode: state.uri.queryParameters['passcode'],
        ),
      ),
      GoRoute(
        // Public, like a share link — the token is the authorization, and
        // requiring a signup to answer a party invitation is the fastest way
        // to collect no RSVPs at all.
        path: '/i/:token',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            InviteScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/gift/:wishlistId/items/:itemId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => GiftItemScreen(
          wishlistId: state.pathParameters['wishlistId']!,
          itemId: state.pathParameters['itemId']!,
        ),
        routes: [
          GoRoute(
            path: 'details',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => GiftDetailsScreen(
              wishlistId: state.pathParameters['wishlistId']!,
              itemId: state.pathParameters['itemId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/gifts/:giftId/confirmed',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            OrderConfirmedScreen(giftId: state.pathParameters['giftId']!),
      ),
      GoRoute(
        path: '/gifts/:giftId/order',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TrackOrderScreen(
          orderRef: OrderRef(
            state.pathParameters['giftId']!,
            OrderLookup.byGiftId,
          ),
        ),
      ),
      GoRoute(
        path: '/orders/:orderId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TrackOrderScreen(
          orderRef: OrderRef(
            state.pathParameters['orderId']!,
            OrderLookup.byOrderId,
          ),
        ),
        routes: [
          GoRoute(
            path: 'delivered',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) =>
                OrderDeliveredScreen(orderId: state.pathParameters['orderId']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.productDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final product = state.extra;
          return switch (product) {
            NormalizedProduct p => ProductDetailScreen.fromSearch(p),
            ResolvedUrlProduct p => ProductDetailScreen.fromResolved(p),
            _ => throw ArgumentError(
              'AppRoutes.productDetail requires a NormalizedProduct or '
              'ResolvedUrlProduct via extra',
            ),
          };
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wishlist,
                builder: (context, state) => const WishlistTabScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    // Pushed on the root navigator, not the branch's — a
                    // create/detail page is full-screen, over the tab bar.
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CreateWishlistScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => WishlistDetailScreen(
                      wishlistId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => CreateWishlistScreen(
                          editing: state.extra as Wishlist?,
                        ),
                      ),
                      GoRoute(
                        path: 'items/:itemId',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => WishlistItemDetailScreen(
                          wishlistId: state.pathParameters['id']!,
                          itemId: state.pathParameters['itemId']!,
                        ),
                      ),
                    ],
                  ),
                ],
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
