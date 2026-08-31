import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../addresses/presentation/address_providers.dart';
import '../../chat/presentation/chat_controller.dart';
import '../../chat/presentation/chat_list_screen.dart';
import '../../chat/presentation/direct_chat_screen.dart';
import '../../discover/presentation/discover_controller.dart';
import '../../events/presentation/create_event_controller.dart';
import '../../events/presentation/invite_controller.dart';
import '../../gifting/presentation/gift_item_controller.dart';
import '../../gifting/presentation/gift_list_providers.dart';
import '../../gifting/presentation/order_controller.dart';
import '../../group_gift/presentation/create_group_gift_controller.dart';
import '../../group_gift/presentation/group_gift_controller.dart';
import '../../group_gift/presentation/group_gift_invite_detail_screen.dart';
import '../../group_gift/presentation/group_gift_invites_screen.dart';
import '../../group_gift/presentation/settlement_controller.dart';
import '../../home/presentation/home_controller.dart';
import '../../memories/presentation/add_wish_controller.dart';
import '../../memories/presentation/create_memory_controller.dart';
import '../../notifications/presentation/notification_providers.dart';
import '../../notifications/presentation/thank_you_controller.dart';
import '../../onboarding/presentation/onboarding_flow_controller.dart';
import '../../onboarding/presentation/onboarding_options_provider.dart';
import '../../onboarding/presentation/profile_controller.dart';
import '../../profile/presentation/edit_profile_controller.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../wishlist/presentation/item_detail_controller.dart';
import '../../wishlist/presentation/manage_access_controller.dart';
import '../../wishlist/presentation/occasion_labels_provider.dart';
import '../../wishlist/presentation/wishlist_detail_controller.dart';
import '../../wishlist/presentation/wishlists_controller.dart';
import '../../wishmates/presentation/wishmates_providers.dart';

/// Drops everything cached while somebody was signed in.
///
/// Every provider below outlives the screens that read it — none is
/// `autoDispose` — so without this they survive a sign-out with the previous
/// user's data still in them. That is not a stale-UI annoyance but a
/// disclosure: the next person to sign in on this handset sees the last one's
/// profile, wishlists, gift counts, notifications and messages until each
/// screen happens to refetch. [SessionController] calls this on every path
/// into and out of a session.
///
/// **The rule is "everything except `sessionProvider`", not "everything that
/// looks user-specific".** Judging it per provider is how one gets missed, and
/// a wrongly-included provider costs only a refetch on a screen the user is
/// leaving anyway — which is why the two taxonomy providers
/// ([onboardingOptionsProvider], [occasionLabelsProvider]) are here despite
/// holding nothing personal. `session_scope_guard_test.dart` fails the build if
/// a new non-`autoDispose` provider appears under `lib/features` without being
/// named here.
///
/// Written out call by call rather than as a list because these have no common
/// supertype that `flutter_riverpod` exports: a list of them infers as
/// `List<Object>`, which `ref.invalidate` will not accept.
///
/// It is not only *fetched* data. The form and wizard controllers
/// ([editProfileProvider], [onboardingFlowProvider], [createEventProvider] and
/// the rest) hold half-typed drafts, and a draft is as personal as a payload —
/// the next user opening Edit Profile must not find the last one's answers in
/// the fields.
///
/// Two providers are deliberately *not* cleared:
///  * `sessionProvider` — the controller doing the clearing.
///  * `signInControllerProvider` — it is what *calls* `accept()`, so clearing
///    it there would dispose the controller mid-`await`.
///
/// `autoDispose` providers are deliberately absent — signing out routes to
/// `/welcome`, unmounting every screen, and an `autoDispose` provider with no
/// listeners disposes itself.
void invalidateSessionScopedProviders(Ref ref) {
  // Profile & account
  ref.invalidate(meProvider);
  ref.invalidate(addressBookProvider);
  ref.invalidate(editProfileProvider);

  // Home, discover, wishlists
  ref.invalidate(homeProvider);
  ref.invalidate(discoverProvider);
  ref.invalidate(wishlistsProvider);
  ref.invalidate(wishlistDetailProvider);
  ref.invalidate(itemDetailProvider);
  ref.invalidate(manageAccessProvider);
  ref.invalidate(occasionLabelsProvider);

  // Gifting & orders
  ref.invalidate(giftListProvider);
  ref.invalidate(giftItemProvider);
  ref.invalidate(orderProvider);

  // Group gifts
  ref.invalidate(createGroupGiftProvider);
  ref.invalidate(groupGiftProvider);
  ref.invalidate(groupGiftInvitesProvider);
  ref.invalidate(groupGiftInviteDetailProvider);
  ref.invalidate(settlementProvider);

  // Events & invitations
  ref.invalidate(createEventProvider);
  ref.invalidate(inviteProvider);

  // Memories
  ref.invalidate(createMemoryProvider);
  ref.invalidate(addWishProvider);

  // Onboarding — including the half-filled wizard, which is per-person.
  ref.invalidate(onboardingOptionsProvider);
  ref.invalidate(onboardingFlowProvider);
  ref.invalidate(profileFormProvider);

  // Notifications & thank-you notes
  ref.invalidate(notificationsProvider);
  ref.invalidate(notificationPreferencesProvider);
  ref.invalidate(thankYouNotesProvider);
  ref.invalidate(thankYouNoteProvider);
  ref.invalidate(thankYouDraftProvider);

  // Chat
  ref.invalidate(chatProvider);
  ref.invalidate(directChatsProvider);
  ref.invalidate(directChatIdProvider);

  // WishMates (Sprint 11)
  ref.invalidate(wishmatesProvider);
  ref.invalidate(pendingRequestCountProvider);
  ref.invalidate(receivedWishLinksProvider);
  ref.invalidate(sentWishLinksProvider);
  ref.invalidate(peopleSuggestionsProvider);
  ref.invalidate(personProfileProvider);
  ref.invalidate(peopleSearchProvider);
}
