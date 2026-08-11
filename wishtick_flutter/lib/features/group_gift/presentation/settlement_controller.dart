import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/group_gift_repository.dart';
import '../domain/settlement.dart';

@immutable
class SettlementState {
  const SettlementState({
    this.balance,
    this.settlements = const [],
    this.error,
    this.busy = false,
  });

  final GroupGiftBalance? balance;
  final List<Settlement> settlements;
  final String? error;
  final bool busy;

  /// True once the host has raised the rows — which is what turns the setup
  /// screen into the progress screen (`4093:444` → `4099:976`).
  bool get hasLedger => settlements.isNotEmpty;

  /// Rows still owing. A confirmed or cancelled row is history.
  List<Settlement> get open =>
      settlements.where((s) => s.status.isOpen).toList();

  SettlementState copyWith({
    GroupGiftBalance? balance,
    List<Settlement>? settlements,
    String? error,
    bool? busy,
    bool clearError = false,
  }) => SettlementState(
    balance: balance ?? this.balance,
    settlements: settlements ?? this.settlements,
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
  );
}

/// Drives the settle-up screens, both directions.
///
/// Balance and ledger load together because neither is meaningful alone: the
/// balance says *whether* anything is owed, the ledger says whether the host
/// has already acted on it, and the screen picks its state from both.
class SettlementController extends Notifier<SettlementState> {
  SettlementController(this.groupGiftId);

  final String groupGiftId;

  @override
  SettlementState build() => const SettlementState();

  GroupGiftRepository get _repo => ref.read(groupGiftRepositoryProvider);

  Future<void> ensureLoaded() async {
    if (state.balance != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final results = await Future.wait([
        _repo.balance(groupGiftId),
        _repo.listSettlements(groupGiftId),
      ]);
      state = SettlementState(
        balance: results[0] as GroupGiftBalance,
        settlements: results[1] as List<Settlement>,
      );
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
    }
  }

  /// Host hands the surplus back. Omit [custom] for the "Split equally"
  /// default the design pre-selects.
  Future<bool> distributeReturn({
    List<({String contributorId, int amountMinor})>? custom,
    String? note,
  }) => _act(
    () => _repo.distributeReturn(groupGiftId, custom: custom, note: note),
  );

  /// Host asks for more because the price moved. Raises the target as well as
  /// the rows, so the progress bar cannot keep claiming the group is funded.
  Future<bool> requestTopUp({
    required int additionalAmountMinor,
    String? note,
  }) => _act(
    () => _repo.requestTopUp(
      groupGiftId,
      additionalAmountMinor: additionalAmountMinor,
      note: note,
    ),
  );

  /// The receiver publishes where to send it (`4095:611`).
  Future<bool> shareUpi(
    String settlementId, {
    required String upiId,
    bool saveToProfile = false,
  }) => _actOne(
    () => _repo.shareUpi(
      settlementId,
      upiId: upiId,
      saveToProfile: saveToProfile,
    ),
  );

  /// The payer's claim. Does not close the row — only the receiver can.
  Future<bool> markSent(String settlementId) =>
      _actOne(() => _repo.markSent(settlementId));

  Future<bool> confirmReceived(String settlementId) =>
      _actOne(() => _repo.confirmReceived(settlementId));

  /// Runs an action that raises rows, then reloads — the balance moves too.
  Future<bool> _act(Future<List<Settlement>> Function() call) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await call();
      await refresh();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }

  /// Runs an action on one row and splices the answer in.
  ///
  /// No refetch: the server returns the updated row, and replacing it in place
  /// keeps the list from flickering while six of them are marked in a row.
  /// The balance is unaffected — marking a payment sent moves no money.
  Future<bool> _actOne(Future<Settlement> Function() call) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final updated = await call();
      state = state.copyWith(
        busy: false,
        settlements: [
          for (final row in state.settlements)
            if (row.id == updated.id) updated else row,
        ],
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    }
  }
}

final settlementProvider =
    NotifierProvider.family<SettlementController, SettlementState, String>(
      SettlementController.new,
    );
