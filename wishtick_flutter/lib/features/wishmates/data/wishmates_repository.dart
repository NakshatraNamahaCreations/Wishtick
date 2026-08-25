import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/wishmate.dart';

/// The connection graph (`4177:138`, `4177:77`, `4177:111`, `4177:42`,
/// `4177:217`, `4177:267`).
///
/// A "WishLink" is one request; a "WishMate" is an accepted one. Received and
/// Sent are the same pending rows read from opposite ends, which is why
/// [listReceived] and [listSent] return the same type.
class WishmatesRepository {
  WishmatesRepository(this._api);

  final ApiClient _api;

  // ── Handles ───────────────────────────────────────────────────────────────

  /// Claims or changes the signed-in user's `@handle`.
  ///
  /// Throws `USERNAME_TAKEN` (409) or `USERNAME_INVALID` (400) — the two the
  /// claim screen renders inline rather than as a snackbar.
  Future<Wishmate> setUsername(String username) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/me/username',
      body: {'username': username},
    );
    return Wishmate.fromJson(json);
  }

  /// Whether a handle can be claimed. Advisory only — the unique index is what
  /// actually settles it, so [setUsername] can still fail after this says yes.
  Future<bool> isUsernameAvailable(String username) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/usernames/$username/available',
    );
    return json['available'] as bool? ?? false;
  }

  // ── Finding people ────────────────────────────────────────────────────────

  /// `4177:42`. Only accounts that claimed a handle are discoverable, and the
  /// server ignores a leading `@`.
  Future<List<Wishmate>> search(String query, {int? limit}) async {
    final json = await _api.get<List<dynamic>>(
      '/people/search',
      query: {'q': query, 'limit': ?limit},
    );
    return json
        .map((e) => Wishmate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// "People You May Know" — friends of friends, ranked by shared WishMates.
  Future<List<Wishmate>> suggestions() async {
    final json = await _api.get<List<dynamic>>('/people/suggestions');
    return json
        .map((e) => Wishmate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WishmateProfile> profile(String userId) async {
    final json = await _api.get<Map<String, dynamic>>('/people/$userId');
    return WishmateProfile.fromJson(json);
  }

  // ── The graph ─────────────────────────────────────────────────────────────

  Future<List<Wishmate>> listMates() async {
    final json = await _api.get<List<dynamic>>('/wishmates');
    return json
        .map((e) => Wishmate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The count the WishMates screen's "N New Requests" banner announces.
  Future<int> pendingCount() async {
    final json = await _api.get<Map<String, dynamic>>(
      '/wishmates/pending-count',
    );
    return json['count'] as int? ?? 0;
  }

  Future<List<WishLink>> listReceived() => _links('received');

  Future<List<WishLink>> listSent() => _links('sent');

  Future<List<WishLink>> _links(String direction) async {
    final json = await _api.get<List<dynamic>>('/wishlinks/$direction');
    return json
        .map((e) => WishLink.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends a request — or accepts one already waiting, which is why this
  /// returns the resulting relationship rather than void. If they asked first,
  /// asking back is consent and the answer is [WishmateRelationship.wishmates].
  Future<WishmateRelationship> request(String userId) =>
      _relationship(_api.post<Map<String, dynamic>>('/people/$userId/request'));

  Future<WishmateRelationship> accept(String linkId) => _relationship(
    _api.post<Map<String, dynamic>>('/wishlinks/$linkId/accept'),
  );

  /// Declining resolves to [WishmateRelationship.none] — indistinguishable
  /// from never having been asked, which is what the sender will see.
  Future<WishmateRelationship> decline(String linkId) => _relationship(
    _api.post<Map<String, dynamic>>('/wishlinks/$linkId/decline'),
  );

  /// The Sent tab's Delete. Withdrawing removes the row outright, unlike a
  /// decline, so the same person can be asked again later.
  Future<void> withdraw(String linkId) =>
      _api.delete<void>('/wishlinks/$linkId');

  Future<void> remove(String userId) => _api.delete<void>('/wishmates/$userId');

  Future<WishmateRelationship> _relationship(
    Future<Map<String, dynamic>> call,
  ) async {
    final json = await call;
    return WishmateRelationship.fromWire(json['relationship'] as String?);
  }
}

final wishmatesRepositoryProvider = Provider<WishmatesRepository>((ref) {
  return WishmatesRepository(ref.watch(apiClientProvider));
});
