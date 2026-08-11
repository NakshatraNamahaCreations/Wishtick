import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/group_gift_repository.dart';
import '../domain/group_gift.dart';

@immutable
class GroupGiftState {
  const GroupGiftState({this.gift, this.error, this.busy = false});

  final GroupGift? gift;
  final String? error;
  final bool busy;

  GroupGiftState copyWith({
    GroupGift? gift,
    String? error,
    bool? busy,
    bool clearError = false,
  }) => GroupGiftState(
    gift: gift ?? this.gift,
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
  );
}

/// One group gift, shared by every screen that shows it after creation —
/// summary, charges, details, contribute.
///
/// Every mutation on this module answers with the whole group gift, so each
/// one lands as a straight state replacement rather than a refetch. That
/// matters most on the bill screens, where the Grand Total is server-derived:
/// re-deriving it here is how the total and its breakdown drift apart.
class GroupGiftController extends Notifier<GroupGiftState> {
  GroupGiftController(this.groupGiftId);

  final String groupGiftId;

  @override
  GroupGiftState build() => const GroupGiftState();

  GroupGiftRepository get _repo => ref.read(groupGiftRepositoryProvider);

  /// Seeds the controller with a gift the caller already has — the create flow
  /// hands the freshly-created one straight to the summary rather than making
  /// the user watch it load again.
  void seed(GroupGift gift) => state = GroupGiftState(gift: gift);

  Future<void> ensureLoaded() async {
    if (state.gift != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, clearError: true);
    await _run(() => _repo.get(groupGiftId));
  }

  // ── The bill ──────────────────────────────────────────────────────────

  Future<bool> addCharge({required String label, required int amountMinor}) =>
      _mutate(
        () => _repo.addCharge(
          groupGiftId,
          label: label,
          amountMinor: amountMinor,
        ),
      );

  Future<bool> updateCharge(
    String chargeId, {
    required String label,
    required int amountMinor,
  }) => _mutate(
    () => _repo.updateCharge(
      groupGiftId,
      chargeId,
      label: label,
      amountMinor: amountMinor,
    ),
  );

  Future<bool> removeCharge(String chargeId) =>
      _mutate(() => _repo.removeCharge(groupGiftId, chargeId));

  Future<bool> addGiftLine(String itemId) =>
      _mutate(() => _repo.addGiftLine(groupGiftId, itemId));

  /// Adds a catalogue product — creates the item, then claims it.
  Future<bool> addGiftLineFromProduct({
    required String provider,
    required String externalId,
  }) => _mutate(
    () => _repo.addGiftLineFromProduct(
      groupGiftId,
      provider: provider,
      externalId: externalId,
    ),
  );

  Future<bool> removeGiftLine(String lineId) =>
      _mutate(() => _repo.removeGiftLine(groupGiftId, lineId));

  // ── Money ─────────────────────────────────────────────────────────────

  Future<bool> contribute({
    required int amountMinor,
    String? message,
    bool anonymous = false,
    String? idempotencyKey,
  }) => _mutate(
    () => _repo.contribute(
      groupGiftId,
      amountMinor: amountMinor,
      message: message,
      anonymous: anonymous,
      idempotencyKey: idempotencyKey,
    ),
  );

  Future<bool> removeContribution(String contributionId) =>
      _mutate(() => _repo.removeContribution(groupGiftId, contributionId));

  /// The recipient's thank-you note (`2219:603`). 403 for anyone else, 409
  /// until the gift has been bought — both surfaced as the server's message.
  Future<bool> setThankYou(String note) =>
      _mutate(() => _repo.setThankYou(groupGiftId, note));

  Future<bool> cancel({String? note}) =>
      _mutate(() => _repo.cancel(groupGiftId, note: note));

  Future<bool> _mutate(Future<GroupGift> Function() call) async {
    state = state.copyWith(busy: true, clearError: true);
    return _run(call);
  }

  Future<bool> _run(Future<GroupGift> Function() call) async {
    try {
      state = GroupGiftState(gift: await call());
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    }
  }

  /// The two 409s a bill screen can actually provoke, said in the terms the
  /// user is looking at rather than as a raw code.
  String _message(ApiException e) => switch (e.code) {
    'GROUP_GIFT_BILL_LOCKED' =>
      'Someone has already chipped in, so the amount is locked. '
          'Ask for more with a contribution request instead.',
    'ITEM_NOT_AVAILABLE' ||
    'ITEM_ALREADY_CLAIMED' => 'Someone else has already claimed that item.',
    _ => e.message,
  };
}

final groupGiftProvider =
    NotifierProvider.family<GroupGiftController, GroupGiftState, String>(
      GroupGiftController.new,
    );
