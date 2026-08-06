import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/public_invite.dart';

/// The invitee side of an event.
///
/// Both routes are unauthenticated — the token *is* the authorization. A signed
/// in guest still sends their bearer (the client attaches it globally), which
/// is what links the invite to their account and lets an event-only wishlist
/// resolve for them afterwards.
class InviteRepository {
  InviteRepository(this._api);

  final ApiClient _api;

  /// Opens an invite. Throws `INVITE_TOKEN_INVALID` (404) for an unknown token.
  /// A cancelled event still resolves — "cancelled" is information the guest
  /// needs more than a 404.
  Future<PublicInvite> getByToken(String token) async {
    final json = await _api.get<Map<String, dynamic>>('/public/invites/$token');
    return PublicInvite.fromJson(json);
  }

  /// Answers the invite and returns the freshly resolved view — which may now
  /// include wishlists that were hidden before, since saying yes is what opens
  /// an event-only list.
  ///
  /// Idempotent: changing your mind is expected. Throws `EVENT_CANCELLED` or
  /// `EVENT_NOT_PUBLISHED` (both 409).
  Future<PublicInvite> rsvp(
    String token, {
    required RsvpResponse response,
    int? plusOnes,
    String? message,
    String? name,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/public/invites/$token/rsvp',
      body: {
        'response': response.wireValue,
        'plusOnes': ?plusOnes,
        'message': ?message,
        'name': ?name,
      },
    );
    return PublicInvite.fromJson(json);
  }
}

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepository(ref.watch(apiClientProvider));
});
