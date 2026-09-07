import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/dev/dev_addresses_repository.dart';
import 'core/dev/dev_gifting_repositories.dart';
import 'core/dev/dev_home_repositories.dart';
import 'core/dev/dev_mode.dart';
import 'core/dev/dev_repositories.dart';
import 'core/media/media_repository.dart';
import 'core/push/firebase_push_service.dart';
import 'core/push/local_notifications.dart';
import 'core/push/push_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/addresses/data/addresses_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/session_controller.dart';
import 'features/discover/data/discover_repository.dart';
import 'features/events/data/invite_repository.dart';
import 'features/gifting/data/gifting_repository.dart';
import 'features/home/data/home_repository.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/wishlist/data/product_repository.dart';
import 'features/wishlist/data/wishlist_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The status bar stays visible — Flutter's default system UI mode already
  // draws it transparently over content and lets `SafeArea` (used throughout
  // the app) keep everything else clear of it. Two attempts at hiding it
  // (`SystemUiMode.manual` with a partial overlay list, then
  // `immersiveSticky`) both left the bar's own space rendered as a solid
  // black strip on real devices instead of the app showing through — the OS
  // reserved the region without repainting it either way. Not worth
  // fighting a second time for a look the design doesn't actually call for
  // anywhere except the one hero image that already sits behind it on
  // purpose (see welcome_screen.dart).

  // Before anything reads FirebaseMessaging. The Android config comes from
  // `android/app/google-services.json`, which the Gradle plugin compiles into
  // resources, so there are no options to pass here.
  //

  // Failure is survivable and deliberately not fatal: a build with the config
  // missing, or a device with no Play Services, should still open the app —
  // it simply never registers for push. `pushEnabled` is what the rest of
  // startup keys off.
  var pushEnabled = false;
  try {
    await Firebase.initializeApp();
    // Registered before runApp so a notification that arrives while the app is
    // terminated has a handler to wake into. Must be a top-level function —
    // Android runs it in its own isolate. See firebase_push_service.dart.
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    pushEnabled = true;
  } on Exception catch (error) {
    debugPrint('Firebase unavailable; push is off for this run: $error');
  }

  // Resolved before the first frame so the saved theme applies immediately —
  // otherwise the app renders one frame in the wrong brightness.
  final prefs = await SharedPreferences.getInstance();

  // Built once so Home and Discover read the same saved dates. Cheap enough to
  // construct outside the DevMode branch; nothing touches it otherwise.
  final devHome = DevHomeRepository(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Left unoverridden when Firebase did not start, in which case the
        // provider stays null and PushRegistrar is never built — the app runs
        // exactly as before, without push.
        if (pushEnabled) ...[
          pushServiceProvider.overrideWithValue(FirebasePushService()),
          // Draws the ones that arrive while the app is open, which FCM hands
          // to the app rather than the tray. Gated on the same flag: without
          // Firebase there is nothing to draw.
          localNotificationsProvider.overrideWithValue(
            FlutterLocalNotifications(),
          ),
        ],
        // A rejected refresh token must sign the user out, not just clear
        // storage — see session_controller.dart.
        sessionExpiryOverride,
        // Debug-only, opt-in: run the whole app against in-memory fakes. Both
        // repositories are swapped together — faking auth alone would sign the
        // user in and strand them on the first onboarding screen waiting out a
        // connect timeout. See core/dev/dev_mode.dart.
        if (DevMode.fakeBackend) ...[
          authRepositoryProvider.overrideWithValue(DevAuthRepository(prefs)),
          onboardingRepositoryProvider.overrideWithValue(
            DevOnboardingRepository(prefs),
          ),
          wishlistRepositoryProvider.overrideWithValue(
            DevWishlistRepository(prefs),
          ),
          productRepositoryProvider.overrideWithValue(DevProductRepository()),
          mediaRepositoryProvider.overrideWithValue(DevMediaRepository()),
          homeRepositoryProvider.overrideWithValue(devHome),
          addressesRepositoryProvider.overrideWithValue(
            DevAddressesRepository(prefs),
          ),
          // Discover reads the same saved dates Home does, so it shares the
          // one instance rather than building a second view of them.
          discoverRepositoryProvider.overrideWithValue(
            DevDiscoverRepository(devHome),
          ),
          giftingRepositoryProvider.overrideWithValue(
            DevGiftingRepository(prefs),
          ),
          inviteRepositoryProvider.overrideWithValue(
            DevInviteRepository(prefs),
          ),
        ],
      ],
      child: const WishtickApp(),
    ),
  );
}
