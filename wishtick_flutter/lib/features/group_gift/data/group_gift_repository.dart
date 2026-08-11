import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/idempotency_key.dart';
import '../domain/group_gift.dart';
import '../domain/settlement.dart';

/// Talks to the backend's `group-gifts` module — the gift itself, the bill
/// (charges and extra items), and the settle-up ledger.
///
/// All three live behind one repository because they are one object to the
/// user: every mutation on the bill or the ledger answers with the whole
/// group gift, so a screen never has to stitch two responses together.
class GroupGiftRepository {
  GroupGiftRepository(this._api);

  final ApiClient _api;

  // ── Creating and reading ────────────────────────────────────────────────

  /// Starts a group gift on an item, claiming it exactly as a single
  /// reservation would.
  ///
  /// [idempotencyKey] must be minted **once per user intent** and reused for
  /// every retry of it — a fresh key on a retry claims the item twice.
  ///
  /// Throws [ApiException] with `ITEM_NOT_AVAILABLE` / `ITEM_ALREADY_CLAIMED`
  /// (409, someone got there first) or `CANNOT_GIFT_OWN_ITEM` (403).
  Future<GroupGift> create(
    String itemId, {
    required String title,
    int? targetAmountMinor,
    String? hostUpiId,
    ContributionMode? contributionMode,
    List<int>? suggestedAmountsMinor,
    List<({String label, int amountMinor})>? charges,
    DateTime? deadline,
    String? message,
    String? idempotencyKey,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/items/$itemId/group-gift',
      body: {
        'title': title,
        'targetAmountMinor': ?targetAmountMinor,
        'hostUpiId': ?hostUpiId,
        'contributionMode': ?contributionMode?.wireValue,
        'suggestedAmountsMinor': ?suggestedAmountsMinor,
        'charges': ?charges
            ?.map((c) => {'label': c.label, 'amountMinor': c.amountMinor})
            .toList(),
        'deadline': ?deadline?.toIso8601String(),
        'message': ?message,
      },
      headers: {'Idempotency-Key': idempotencyKey ?? newIdempotencyKey()},
    );
    return GroupGift.fromJson(json);
  }

  Future<GroupGift> get(String id) async {
    final json = await _api.get<Map<String, dynamic>>('/group-gifts/$id');
    return GroupGift.fromJson(json);
  }

  /// Group gifts the caller takes part in — initiated, joined, or contributed
  /// to — newest first.
  Future<List<GroupGift>> listMine({int? limit}) async {
    final json = await _api.get<List<dynamic>>(
      '/group-gifts/mine',
      query: {'limit': ?limit},
    );
    return json
        .map((e) => GroupGift.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── The bill ────────────────────────────────────────────────────────────
  //
  // Editable only while nobody has contributed. Once the first person pays in,
  // the server answers 409 `GROUP_GIFT_BILL_LOCKED` — changing the target
  // afterwards would move the goalposts under people who already committed
  // against the old number.

  /// Adds a non-item cost. Raises the Grand Total by [amountMinor].
  Future<GroupGift> addCharge(
    String id, {
    required String label,
    required int amountMinor,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/group-gifts/$id/charges',
      body: {'label': label, 'amountMinor': amountMinor},
    );
    return GroupGift.fromJson(json);
  }

  /// Edits a charge in place — the pencil on `4007:568`.
  ///
  /// One call rather than remove-then-add: two would leave the charge deleted
  /// if the second failed, silently lowering the Grand Total.
  Future<GroupGift> updateCharge(
    String id,
    String chargeId, {
    required String label,
    required int amountMinor,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/group-gifts/$id/charges/$chargeId',
      body: {'label': label, 'amountMinor': amountMinor},
    );
    return GroupGift.fromJson(json);
  }

  Future<GroupGift> removeCharge(String id, String chargeId) async {
    final json = await _api.delete<Map<String, dynamic>>(
      '/group-gifts/$id/charges/$chargeId',
    );
    return GroupGift.fromJson(json);
  }

  /// Folds a second item into the group, claiming it with its own holder gift.
  Future<GroupGift> addGiftLine(String id, String itemId) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/group-gifts/$id/gifts',
      body: {'itemId': itemId},
    );
    return GroupGift.fromJson(json);
  }

  /// Folds a **catalogue product** into the group, creating the wishlist item
  /// first (`4007:720`).
  ///
  /// The recipient never listed this, so the server creates it on their
  /// wishlist and hides it from them — they did not ask for it, and seeing it
  /// would give the surprise away. The only path on which a non-owner writes
  /// to another person's list; the authority is having initiated this group.
  Future<GroupGift> addGiftLineFromProduct(
    String id, {
    required String provider,
    required String externalId,
    String? notes,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/group-gifts/$id/gifts/from-product',
      body: {'provider': provider, 'externalId': externalId, 'notes': ?notes},
    );
    return GroupGift.fromJson(json);
  }

  /// The summary's `×`. Releases that item's holder gift so it returns to
  /// available. The primary item is not removable — cancel the group instead.
  Future<GroupGift> removeGiftLine(String id, String lineId) async {
    final json = await _api.delete<Map<String, dynamic>>(
      '/group-gifts/$id/gifts/$lineId',
    );
    return GroupGift.fromJson(json);
  }

  // ── Membership and money ────────────────────────────────────────────────

  /// Join as a named member without pledging anything.
  Future<GroupGift> join(String id) async {
    final json = await _api.post<Map<String, dynamic>>('/group-gifts/$id/join');
    return GroupGift.fromJson(json);
  }

  /// Pledge a share.
  ///
  /// A pledge, not a payment: Wishtick never touches the money. The member
  /// pays the host's UPI directly, and the host acknowledges receipt
  /// separately.
  ///
  /// Same idempotency rule as [create] — one key per intent, reused on retry,
  /// or a flaky connection turns one pledge into two.
  Future<GroupGift> contribute(
    String id, {
    required int amountMinor,
    String? message,
    bool? anonymous,
    String? idempotencyKey,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/group-gifts/$id/contribute',
      body: {
        'amountMinor': amountMinor,
        'message': ?message,
        'anonymous': ?anonymous,
      },
      headers: {'Idempotency-Key': idempotencyKey ?? newIdempotencyKey()},
    );
    return GroupGift.fromJson(json);
  }

  Future<GroupGift> removeContribution(String id, String contributionId) async {
    final json = await _api.delete<Map<String, dynamic>>(
      '/group-gifts/$id/contributions/$contributionId',
    );
    return GroupGift.fromJson(json);
  }

  // ── Host-only transitions ───────────────────────────────────────────────

  Future<GroupGift> purchase(String id, {String? note}) =>
      _action(id, 'purchase', note);

  Future<GroupGift> fulfill(String id, {String? note}) =>
      _action(id, 'fulfill', note);

  /// Frees the item and records refunds for any contributions.
  Future<GroupGift> cancel(String id, {String? note}) =>
      _action(id, 'cancel', note);

  Future<GroupGift> _action(String id, String action, String? note) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/group-gifts/$id/$action',
      body: {'note': ?note},
    );
    return GroupGift.fromJson(json);
  }

  /// The recipient writes their thank-you note (`2219:603`).
  ///
  /// 403 for anyone but the person the gift is for; 409 until it has been
  /// bought.
  Future<GroupGift> setThankYou(String id, String note) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/group-gifts/$id/thank-you',
      body: {'note': note},
    );
    return GroupGift.fromJson(json);
  }

  /// Rotate the share slug or set a passcode / expiry.
  Future<GroupGiftShare> configureShare(
    String id, {
    bool? rotate,
    String? passcode,
    DateTime? expiresAt,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/group-gifts/$id/share',
      body: {
        'rotate': ?rotate,
        'passcode': ?passcode,
        'expiresAt': ?expiresAt?.toIso8601String(),
      },
    );
    return GroupGiftShare.fromJson(json);
  }

  // ── Settle up ───────────────────────────────────────────────────────────

  Future<GroupGiftBalance> balance(String id) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/group-gifts/$id/balance',
    );
    return GroupGiftBalance.fromJson(json);
  }

  Future<List<Settlement>> listSettlements(String id) async {
    final json = await _api.get<List<dynamic>>('/group-gifts/$id/settlements');
    return json
        .map((e) => Settlement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Host hands a surplus back — one row per contributor.
  ///
  /// Omit [custom] for the "Split equally" default the design pre-selects;
  /// supplying it is the "Custom Refund" branch of `4093:444`.
  Future<List<Settlement>> distributeReturn(
    String id, {
    List<({String contributorId, int amountMinor})>? custom,
    String? note,
  }) async {
    final json = await _api.post<List<dynamic>>(
      '/group-gifts/$id/settlements/return',
      body: {
        'custom': ?custom
            ?.map(
              (a) => {
                'contributorId': a.contributorId,
                'amountMinor': a.amountMinor,
              },
            )
            .toList(),
        'note': ?note,
      },
    );
    return json
        .map((e) => Settlement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Host asks for more, because the price moved (`4092:174`).
  ///
  /// [additionalAmountMinor] is supplied rather than derived: the bill is
  /// settled before anyone contributes, so more money is only ever needed
  /// because the price changed outside Wishtick — and only the host can see
  /// that. It raises the target as well as raising the rows, so the progress
  /// bar cannot keep insisting the group is fully funded.
  Future<List<Settlement>> requestTopUp(
    String id, {
    required int additionalAmountMinor,
    String? note,
  }) async {
    final json = await _api.post<List<dynamic>>(
      '/group-gifts/$id/settlements/top-up',
      body: {'additionalAmountMinor': additionalAmountMinor, 'note': ?note},
    );
    return json
        .map((e) => Settlement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The receiver publishes where to send it (`4095:611`).
  Future<Settlement> shareUpi(
    String settlementId, {
    required String upiId,
    bool? saveToProfile,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/settlements/$settlementId/upi',
      body: {'upiId': upiId, 'saveToProfile': ?saveToProfile},
    );
    return Settlement.fromJson(json);
  }

  /// The payer's claim that they have paid. Does not close the row.
  ///
  /// 409s if no UPI ID has been shared yet — there was nowhere to send it.
  Future<Settlement> markSent(String settlementId) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/settlements/$settlementId/sent',
    );
    return Settlement.fromJson(json);
  }

  /// The receiver's acknowledgement. Only this closes the row — one person
  /// cannot mark their own debt settled.
  Future<Settlement> confirmReceived(String settlementId) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/settlements/$settlementId/received',
    );
    return Settlement.fromJson(json);
  }
}

final groupGiftRepositoryProvider = Provider<GroupGiftRepository>((ref) {
  return GroupGiftRepository(ref.watch(apiClientProvider));
});
