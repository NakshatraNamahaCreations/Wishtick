import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/addresses/presentation/address_book_screen.dart';
import '../../features/auth/presentation/mobile_number_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/direct_chat_screen.dart';
import '../../features/chat/presentation/group_chat_screen.dart';
import '../../features/events/presentation/create_event_details_screen.dart';
import '../../features/events/presentation/create_event_screen.dart';
import '../../features/events/presentation/event_guest_detail_screen.dart';
import '../../features/events/presentation/event_guests_screen.dart';
import '../../features/events/presentation/event_invite_preview_screen.dart';
import '../../features/events/presentation/event_invite_templates_screen.dart';
import '../../features/events/presentation/invite_screen.dart';
import '../../features/events/presentation/my_events_screen.dart';
import '../../features/events/presentation/upload_invitation_screen.dart';
import '../../features/gifting/presentation/gift_arrival_screen.dart';
import '../../features/gifting/presentation/gift_details_screen.dart';
import '../../features/gifting/presentation/gift_item_screen.dart';
import '../../features/gifting/presentation/gift_list_providers.dart';
import '../../features/gifting/presentation/gift_list_screen.dart';
import '../../features/gifting/presentation/order_confirmed_screen.dart';
import '../../features/gifting/presentation/order_controller.dart';
import '../../features/gifting/presentation/order_delivered_screen.dart';
import '../../features/gifting/presentation/track_order_screen.dart';
import '../../features/group_gift/domain/group_gift.dart';
import '../../features/group_gift/presentation/create_group_gift_screen.dart';
import '../../features/group_gift/presentation/group_gift_add_item_screen.dart';
import '../../features/group_gift/presentation/group_gift_charges_screen.dart';
import '../../features/group_gift/presentation/group_gift_created_screen.dart';
import '../../features/group_gift/presentation/group_gift_details_screen.dart';
import '../../features/group_gift/presentation/group_gift_participants_screen.dart';
import '../../features/group_gift/presentation/group_gift_settle_screen.dart';
import '../../features/group_gift/presentation/group_gift_summary_screen.dart';
import '../../features/group_gift/presentation/group_gift_thank_you_screen.dart';
import '../../features/home/presentation/delivery_location_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/memories/presentation/add_wish_screen.dart';
import '../../features/memories/presentation/create_memory_screen.dart';
import '../../features/memories/presentation/create_memory_unlock_screen.dart';
import '../../features/memories/presentation/memories_tab_screen.dart';
import '../../features/memories/presentation/memory_detail_screen.dart';
import '../../features/memories/presentation/memory_experience_screen.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../features/notifications/presentation/thank_you_compose_screen.dart';
import '../../features/notifications/presentation/thank_you_preview_screen.dart';
import '../../features/notifications/presentation/thank_you_sent_screen.dart';
import '../../features/onboarding/presentation/all_set_screen.dart';
import '../../features/onboarding/presentation/avatar_picker_screen.dart';
import '../../features/onboarding/presentation/category_detail_screen.dart';
import '../../features/onboarding/presentation/colors_screen.dart';
import '../../features/onboarding/presentation/create_profile_screen.dart';
import '../../features/onboarding/presentation/important_dates_screen.dart';
import '../../features/onboarding/presentation/interests_screen.dart';
import '../../features/onboarding/presentation/size_fit_screen.dart';
import '../../features/profile/presentation/about_us_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/help_centre_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/appearance_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/wishlist/domain/product.dart';
import '../../features/wishlist/domain/wishlist.dart';
import '../../features/wishlist/presentation/create_wishlist_screen.dart';
import '../../features/wishlist/presentation/manage_access_screen.dart';
import '../../features/wishlist/presentation/product_detail_screen.dart';
import '../../features/wishlist/presentation/public_wishlist_screen.dart';
import '../../features/wishlist/presentation/wishlist_detail_screen.dart';
import '../../features/wishlist/presentation/wishlist_item_detail_screen.dart';
import '../../features/wishlist/presentation/wishlist_tab_screen.dart';
import '../../features/wishmates/presentation/people_search_screen.dart';
import '../../features/wishmates/presentation/person_profile_screen.dart';
import '../../features/wishmates/presentation/username_claim_screen.dart';
import '../../features/wishmates/presentation/wishlinks_screen.dart';
import '../../features/wishmates/presentation/wishmates_list_screen.dart';
import '../legal/legal_document_screen.dart';
import '../legal/privacy_document.dart';
import '../legal/terms_document.dart';
import '../theme/theme_extensions.dart';
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
      // The Terms and the Privacy Policy are linked from the consent line on
      // the sign-in screen, which is read *before* there is a session. Sending
      // that tap to /welcome would answer "what am I agreeing to?" with the
      // carousel.
      final isLegal = location.startsWith(AppRoutes.legal);

      if (isPublicLink || isLegal) return null;

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

      // ── Profile (Sprint 9) ────────────────────────────────────────────────
      //
      // All pushed over the shell rather than inside the Profile branch: they
      // are full-screen destinations in the frames, with no bottom nav.
      GoRoute(
        path: AppRoutes.editProfile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.giftsReceived,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            const GiftListScreen(kind: GiftListKind.received),
      ),
      GoRoute(
        path: AppRoutes.giftsGiven,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            const GiftListScreen(kind: GiftListKind.given),
      ),
      GoRoute(
        path: AppRoutes.giftsOnHold,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            const GiftListScreen(kind: GiftListKind.onHold),
      ),
      GoRoute(
        path: AppRoutes.myEvents,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyEventsScreen(),
      ),
      GoRoute(
        path: AppRoutes.addressBook,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddressBookScreen(),
      ),
      GoRoute(
        path: AppRoutes.helpCentre,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HelpCentreScreen(),
      ),
      GoRoute(
        path: AppRoutes.aboutUs,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AboutUsScreen(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            const LegalDocumentScreen(document: TermsDocument.document),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            const LegalDocumentScreen(document: PrivacyDocument.document),
      ),

      // ── WishMates (Sprint 11) ─────────────────────────────────────────────
      //
      // All on the root navigator: they are pushed over the tab shell from
      // Home's header and from each other, and none of them belongs to a tab.
      GoRoute(
        path: AppRoutes.usernameClaim,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UsernameClaimScreen(),
      ),
      GoRoute(
        path: AppRoutes.wishmates,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WishmatesListScreen(),
      ),
      GoRoute(
        path: AppRoutes.wishlinks,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => WishLinksScreen(
          // `?tab=sent` so the Sent tab is linkable; Received is the default
          // because that is the one with something waiting on you.
          initialTab: state.uri.queryParameters['tab'] == 'sent' ? 1 : 0,
        ),
      ),
      GoRoute(
        path: AppRoutes.peopleSearch,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PeopleSearchScreen(),
      ),
      GoRoute(
        // Nested under the search route so `/people/:id` cannot be mistaken
        // for a query on `/people`.
        path: '/people/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PersonProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: AppRoutes.chats,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chats/direct/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            DirectChatScreen(userId: state.pathParameters['userId']!),
      ),

      // ── Notifications (Sprint 9) ──────────────────────────────────────────
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/gifts/:giftId/arrived',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            GiftArrivalScreen(giftId: state.pathParameters['giftId']!),
      ),
      GoRoute(
        path: '/thank-you/:noteId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ThankYouComposeScreen(noteId: state.pathParameters['noteId']!),
        routes: [
          GoRoute(
            path: 'preview',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) =>
                ThankYouPreviewScreen(noteId: state.pathParameters['noteId']!),
          ),
          GoRoute(
            path: 'sent',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) =>
                ThankYouSentScreen(noteId: state.pathParameters['noteId']!),
          ),
        ],
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
          GoRoute(
            path: 'group',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => CreateGroupGiftScreen(
              wishlistId: state.pathParameters['wishlistId']!,
              itemId: state.pathParameters['itemId']!,
            ),
          ),
        ],
      ),

      // Group gifting (Sprint 6b). Creation is four screens deep, so each step
      // is a child route — backing out of charges lands on the summary rather
      // than abandoning a group that already exists server-side.
      GoRoute(
        path: '/group-gifts/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            GroupGiftDetailsScreen(groupGiftId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'summary',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => GroupGiftSummaryScreen(
              groupGiftId: state.pathParameters['id']!,
              // Handed over by the create screen so the summary paints with
              // real numbers instead of refetching what it was just given.
              initial: state.extra as GroupGift?,
            ),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => GroupGiftAddItemScreen(
                  groupGiftId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'charges',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => GroupGiftChargesScreen(
              groupGiftId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'created',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => GroupGiftCreatedScreen(
              groupGiftId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'participants',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => GroupGiftParticipantsScreen(
              groupGiftId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'chat',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => GroupChatScreen(
              groupGiftId: state.pathParameters['id']!,
              chatId: state.extra! as String,
            ),
          ),
          GoRoute(
            path: 'thank-you',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => GroupGiftThankYouScreen(
              groupGiftId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'settle',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) =>
                GroupGiftSettleScreen(groupGiftId: state.pathParameters['id']!),
          ),
        ],
      ),
      // Events, host side (Sprint 7). The two create steps are siblings rather
      // than nested: one controller holds the wizard, so backing out of step 2
      // must land on step 1 with what was typed still there.
      GoRoute(
        path: AppRoutes.createEvent,
        parentNavigatorKey: _rootNavigatorKey,
        // Non-opaque: `257:733` is a sheet over a dimmed page, and the close
        // button floats in the gap above it. An opaque page would paint that
        // gap a flat colour instead.
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          opaque: false,
          barrierDismissible: false,
          barrierColor: context.colors.overlay,
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          child: const CreateEventScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.createEventDetails,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateEventDetailsScreen(),
      ),
      GoRoute(
        path: '/events/:id/invite',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            EventInviteTemplatesScreen(eventId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'upload',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) =>
                UploadInvitationScreen(eventId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'preview',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) =>
                EventInvitePreviewScreen(eventId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/events/:id/guests',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            EventGuestsScreen(eventId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: ':inviteId',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => EventGuestDetailScreen(
              eventId: state.pathParameters['id']!,
              inviteId: state.pathParameters['inviteId']!,
            ),
          ),
        ],
      ),
      // Memories (Sprint 8). The two create steps are siblings, as the events
      // wizard's are, so backing out of step 2 keeps what was typed.
      GoRoute(
        path: AppRoutes.createMemory,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateMemoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.createMemoryUnlock,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateMemoryUnlockScreen(),
      ),
      GoRoute(
        path: '/memories/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            MemoryDetailScreen(memoryId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'wishes/add',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) =>
                AddWishScreen(memoryId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'experience',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) =>
                MemoryExperienceScreen(memoryId: state.pathParameters['id']!),
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
                        path: 'access',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => ManageAccessScreen(
                          // Reached only from the wishlist itself, which
                          // already has the loaded list — passing it avoids a
                          // second fetch of what the caller is looking at.
                          wishlist: state.extra! as Wishlist,
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
                builder: (context, state) => const MemoriesTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
