import 'package:wishtick_flutter/core/network/api_exception.dart';
import 'package:wishtick_flutter/features/group_gift/data/group_gift_repository.dart';
import 'package:wishtick_flutter/features/group_gift/domain/group_gift.dart';
import 'package:wishtick_flutter/features/group_gift/domain/settlement.dart';

/// The design's own numbers: ₹16,999 handbag + ₹199 delivery + ₹149
/// packaging = a ₹17,347 Grand Total (`4006:463`).
const kItemMinor = 1699900;
const kDeliveryMinor = 19900;
const kPackagingMinor = 14900;
const kGrandTotalMinor = kItemMinor + kDeliveryMinor + kPackagingMinor;

GroupGiftCharge buildCharge({
  String id = 'charge_1',
  String label = 'Delivery Charges',
  int amountMinor = kDeliveryMinor,
}) => GroupGiftCharge(
  id: id,
  label: label,
  amountMinor: amountMinor,
  addedBy: 'host_1',
  addedAt: DateTime(2026, 8, 1),
);

GroupGiftItem buildItem({
  String itemId = 'item_1',
  String? lineId,
  String title = 'Michael Kors Women Handbag',
  int? amountMinor = kItemMinor,
}) => GroupGiftItem(
  lineId: lineId,
  itemId: itemId,
  title: title,
  amountMinor: amountMinor,
  removable: lineId != null,
);

GroupGift buildGroupGift({
  String id = 'gg_1',
  String hostId = 'host_1',
  GroupGiftStatus status = GroupGiftStatus.open,
  int targetAmountMinor = kGrandTotalMinor,
  int collectedAmountMinor = 0,
  int chargesTotalMinor = 0,
  List<GroupGiftCharge> charges = const [],
  List<GroupGiftItem>? items,
  List<GroupGiftParticipant> participants = const [],
  List<GroupGiftContribution> recentContributions = const [],
  List<int> suggestedAmountsMinor = const [50000, 100000, 200000],
  String? hostUpiId = 'rohanr1@okaxis',
  String? thankYouNote,
  String? recipientName = 'Siya',
  GroupGiftShare? share,
}) => GroupGift(
  id: id,
  itemId: 'item_1',
  wishlistId: 'wl_1',
  status: status,
  title: "Siya's birthday gift",
  hostId: hostId,
  hostUpiId: hostUpiId,
  suggestedAmountsMinor: suggestedAmountsMinor,
  targetAmountMinor: targetAmountMinor,
  chargesTotalMinor: chargesTotalMinor,
  charges: charges,
  items: items ?? [buildItem()],
  collectedAmountMinor: collectedAmountMinor,
  currency: 'INR',
  percentFunded: targetAmountMinor == 0
      ? 0
      : (collectedAmountMinor * 100 ~/ targetAmountMinor).clamp(0, 100),
  contributorCount: 0,
  participantCount: participants.length,
  participants: participants,
  recentContributions: recentContributions,
  myContributionMinor: 0,
  createdAt: DateTime(2026, 8, 1),
  thankYouNote: thankYouNote,
  recipientName: recipientName,
  share: share,
);

GroupGiftInvite buildInvite({
  String id = 'inv_1',
  String groupGiftId = 'gg_1',
  String groupTitle = "Siya's birthday gift",
  String inviterName = 'Rohan',
}) => GroupGiftInvite(
  id: id,
  groupGiftId: groupGiftId,
  groupTitle: groupTitle,
  status: 'pending',
  invitedById: 'host_1',
  inviterName: inviterName,
  createdAt: DateTime(2026, 8, 1),
);

GroupGiftInviteDetail buildInviteDetail({
  GroupGiftInvite? invite,
  String itemTitle = 'Lightbeam Android 14 Smart LED Projector',
  String? imageUrl,
  int targetAmountMinor = 487100,
  int collectedAmountMinor = 100000,
  int contributorCount = 1,
  List<GroupGiftInviteContributor>? contributors,
}) => GroupGiftInviteDetail(
  invite: invite ?? buildInvite(),
  itemTitle: itemTitle,
  imageUrl: imageUrl,
  currency: 'INR',
  targetAmountMinor: targetAmountMinor,
  collectedAmountMinor: collectedAmountMinor,
  percentFunded: targetAmountMinor == 0
      ? 0
      : (collectedAmountMinor * 100 ~/ targetAmountMinor).clamp(0, 100),
  contributorCount: contributorCount,
  contributors:
      contributors ??
      const [
        GroupGiftInviteContributor(
          userId: 'host_1',
          name: 'Rohan',
          amountMinor: 100000,
        ),
      ],
);

Settlement buildSettlement({
  String id = 'st_1',
  String contributorId = 'user_2',
  String hostId = 'host_1',
  SettlementDirection direction = SettlementDirection.returnToContributors,
  int amountMinor = 33300,
  SettlementStatus status = SettlementStatus.pending,
  String? upiId,
}) => Settlement(
  id: id,
  groupGiftId: 'gg_1',
  contributorId: contributorId,
  hostId: hostId,
  direction: direction,
  amountMinor: amountMinor,
  currency: 'INR',
  status: status,
  upiId: upiId,
  createdAt: DateTime(2026, 8, 1),
);

/// An in-memory stand-in that records what it was asked to do, so a test can
/// assert on the *call* — which is the only place a wrong idempotency key or a
/// dropped field would ever show up.
class FakeGroupGiftRepository implements GroupGiftRepository {
  FakeGroupGiftRepository({
    GroupGift? gift,
    this.stubBalance,
    List<Settlement>? settlements,
    this.failWith,
  }) : gift = gift ?? buildGroupGift(),
       settlements = settlements ?? [];

  GroupGift gift;
  GroupGiftBalance? stubBalance;
  List<Settlement> settlements;

  /// When set, every call throws it — the error paths matter as much as the
  /// happy ones on money screens.
  Object? failWith;

  final calls = <String>[];
  final createArgs = <Map<String, Object?>>[];

  T _guard<T>(T value) {
    if (failWith != null) throw failWith!;
    return value;
  }

  @override
  Future<GroupGift> create(
    String itemId, {
    required String title,
    int? targetAmountMinor,
    String? hostUpiId,
    ContributionMode? contributionMode,
    List<int>? suggestedAmountsMinor,
    List<({int amountMinor, String label})>? charges,
    DateTime? deadline,
    String? message,
    String? idempotencyKey,
  }) async {
    calls.add('create');
    createArgs.add({
      'itemId': itemId,
      'title': title,
      'targetAmountMinor': targetAmountMinor,
      'hostUpiId': hostUpiId,
      'contributionMode': contributionMode,
      'suggestedAmountsMinor': suggestedAmountsMinor,
      'message': message,
      'idempotencyKey': idempotencyKey,
    });
    return _guard(gift);
  }

  @override
  Future<GroupGift> get(String id) async {
    calls.add('get');
    return _guard(gift);
  }

  @override
  Future<List<GroupGift>> listMine({int? limit}) async => _guard([gift]);

  /// What the server answered the last invite with. The skip count is not
  /// cosmetic — the screen has to say it out loud — so it is stubbable.
  ({int invited, int skipped}) inviteResult = (invited: 0, skipped: 0);

  /// Exactly who was asked, in order, so a test can catch the picker's
  /// selection being dropped or reordered on the way to the wire.
  final invitedUserIds = <List<String>>[];

  /// What the invitee's list answers with.
  List<GroupGiftInvite> invites = const [];

  /// Every answer sent, as (inviteId, accepted). Recorded rather than counted:
  /// a screen that sends accept when the Decline button was pressed would pass
  /// a call-count assertion and fail this one.
  final respondedTo = <(String, bool)>[];

  @override
  Future<List<GroupGiftInvite>> listInvites() async {
    calls.add('listInvites');
    return _guard(invites);
  }

  /// What the detail screen is handed. Null means the call throws not-found,
  /// which is what a stale invite id does on the server.
  GroupGiftInviteDetail? inviteDetail0;

  @override
  Future<GroupGiftInviteDetail> inviteDetail(String inviteId) async {
    calls.add('inviteDetail');
    final detail = _guard(inviteDetail0);
    if (detail == null) {
      throw const ApiException(
        code: 'NOT_FOUND',
        message: 'Invitation not found',
      );
    }
    return detail;
  }

  @override
  Future<void> respondToInvite(String inviteId, {required bool accept}) async {
    calls.add('respondToInvite');
    _guard(null);
    respondedTo.add((inviteId, accept));
  }

  @override
  Future<({int invited, int skipped})> invite(
    String groupGiftId,
    List<String> userIds,
  ) async {
    calls.add('invite');
    invitedUserIds.add(userIds);
    return _guard(inviteResult);
  }

  @override
  Future<GroupGift> addCharge(
    String id, {
    required String label,
    required int amountMinor,
  }) async {
    calls.add('addCharge');
    return _guard(gift);
  }

  @override
  Future<GroupGift> updateCharge(
    String id,
    String chargeId, {
    required String label,
    required int amountMinor,
  }) async {
    calls.add('updateCharge');
    return _guard(gift);
  }

  @override
  Future<GroupGift> removeCharge(String id, String chargeId) async {
    calls.add('removeCharge');
    return _guard(gift);
  }

  @override
  Future<GroupGift> addGiftLine(String id, String itemId) async {
    calls.add('addGiftLine');
    return _guard(gift);
  }

  @override
  Future<GroupGift> addGiftLineFromProduct(
    String id, {
    required String provider,
    required String externalId,
    String? notes,
  }) async {
    calls.add('addGiftLineFromProduct:$provider/$externalId');
    return _guard(gift);
  }

  @override
  Future<GroupGift> removeGiftLine(String id, String lineId) async {
    calls.add('removeGiftLine:$lineId');
    return _guard(gift);
  }

  @override
  Future<GroupGift> join(String id) async => _guard(gift);

  @override
  Future<GroupGift> contribute(
    String id, {
    required int amountMinor,
    String? message,
    bool? anonymous,
    String? idempotencyKey,
  }) async {
    calls.add('contribute:$amountMinor:$idempotencyKey');
    return _guard(gift);
  }

  @override
  Future<GroupGift> removeContribution(
    String id,
    String contributionId,
  ) async => _guard(gift);

  @override
  Future<GroupGift> purchase(String id, {String? note}) async => _guard(gift);

  @override
  Future<GroupGift> fulfill(String id, {String? note}) async => _guard(gift);

  @override
  Future<GroupGift> cancel(String id, {String? note}) async => _guard(gift);

  @override
  Future<GroupGift> setThankYou(String id, String note) async {
    calls.add('setThankYou:$note');
    return _guard(gift);
  }

  @override
  Future<GroupGiftShare> configureShare(
    String id, {
    bool? rotate,
    String? passcode,
    DateTime? expiresAt,
  }) async =>
      _guard(const GroupGiftShare(slug: 's', url: 'u', hasPasscode: false));

  @override
  Future<GroupGiftBalance> balance(String id) async {
    calls.add('balance');
    return _guard(
      stubBalance ??
          const GroupGiftBalance(
            totalCostMinor: kGrandTotalMinor,
            pledgedMinor: 0,
            collectedMinor: 0,
            differenceMinor: 0,
            contributorCount: 0,
          ),
    );
  }

  @override
  Future<List<Settlement>> listSettlements(String id) async {
    calls.add('listSettlements');
    return _guard(settlements);
  }

  @override
  Future<List<Settlement>> distributeReturn(
    String id, {
    List<({int amountMinor, String contributorId})>? custom,
    String? note,
  }) async {
    calls.add('distributeReturn');
    return _guard(settlements);
  }

  @override
  Future<List<Settlement>> requestTopUp(
    String id, {
    required int additionalAmountMinor,
    String? note,
  }) async {
    calls.add('requestTopUp:$additionalAmountMinor');
    return _guard(settlements);
  }

  @override
  Future<Settlement> shareUpi(
    String settlementId, {
    required String upiId,
    bool? saveToProfile,
  }) async {
    calls.add('shareUpi:$upiId:$saveToProfile');
    return _guard(buildSettlement(id: settlementId, upiId: upiId));
  }

  @override
  Future<Settlement> markSent(String settlementId) async {
    calls.add('markSent:$settlementId');
    return _guard(
      buildSettlement(
        id: settlementId,
        status: SettlementStatus.sent,
        upiId: 'x@upi',
      ),
    );
  }

  @override
  Future<Settlement> confirmReceived(String settlementId) async {
    calls.add('confirmReceived:$settlementId');
    return _guard(
      buildSettlement(
        id: settlementId,
        status: SettlementStatus.confirmed,
        upiId: 'x@upi',
      ),
    );
  }
}
