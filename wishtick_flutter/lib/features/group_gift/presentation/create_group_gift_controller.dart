import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/idempotency_key.dart';
import '../data/group_gift_repository.dart';
import '../domain/group_gift.dart';

/// The chips `299:1658` ships with, in minor units.
const kDefaultSuggestedAmountsMinor = [50000, 100000, 200000];

/// The "Quick Suggestions ✦" presets under the message field.
const kQuickMessageSuggestions = [
  'Happy birthday {name}!',
  'Special Gift for {name}!',
  "Let's make {name}'s birthday special.",
];

@immutable
class CreateGroupGiftState {
  const CreateGroupGiftState({
    this.goalAmountMinor,
    this.mode = ContributionMode.equal,
    this.suggestedAmountsMinor = kDefaultSuggestedAmountsMinor,
    this.customAmountMinor,
    this.upiId = '',
    this.title = '',
    this.message = '',
    this.error,
    this.busy = false,
    this.created,
  });

  /// Defaults to the item's price, and stays editable — the host may know the
  /// thing is cheaper elsewhere.
  final int? goalAmountMinor;

  final ContributionMode mode;
  final List<int> suggestedAmountsMinor;

  /// The "Custom Amount (Optional)" field — a fourth chip the host adds, not a
  /// replacement for the three.
  final int? customAmountMinor;

  final String upiId;
  final String title;
  final String message;
  final String? error;
  final bool busy;

  /// Set once the server has accepted it; the summary screen takes over here.
  final GroupGift? created;

  /// Title is the only required field (`299:1658` marks it with a red
  /// asterisk), and there must be somewhere to send the money — nobody can be
  /// asked to pay into a blank UPI ID.
  bool get canSubmit =>
      !busy &&
      title.trim().isNotEmpty &&
      upiId.trim().isNotEmpty &&
      (goalAmountMinor ?? 0) > 0;

  /// The chips as the contribute sheet will see them: the host's three plus
  /// their custom one, de-duplicated and ordered, so a custom ₹1,500 slots
  /// between ₹1,000 and ₹2,000 rather than trailing them.
  List<int> get allSuggestedAmountsMinor {
    final custom = customAmountMinor;
    final all = {
      ...suggestedAmountsMinor,
      if (custom != null && custom > 0) custom,
    };
    return all.toList()..sort();
  }

  CreateGroupGiftState copyWith({
    int? goalAmountMinor,
    ContributionMode? mode,
    List<int>? suggestedAmountsMinor,
    int? customAmountMinor,
    String? upiId,
    String? title,
    String? message,
    String? error,
    bool? busy,
    GroupGift? created,
    bool clearError = false,
    bool clearCustomAmount = false,
  }) => CreateGroupGiftState(
    goalAmountMinor: goalAmountMinor ?? this.goalAmountMinor,
    mode: mode ?? this.mode,
    suggestedAmountsMinor: suggestedAmountsMinor ?? this.suggestedAmountsMinor,
    customAmountMinor: clearCustomAmount
        ? null
        : (customAmountMinor ?? this.customAmountMinor),
    upiId: upiId ?? this.upiId,
    title: title ?? this.title,
    message: message ?? this.message,
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
    created: created ?? this.created,
  );
}

/// Drives "Create Group Gift" (`299:1658`).
///
/// Keyed by item, so backing out and coming in again on the same item keeps
/// what was typed, while a different item starts clean.
class CreateGroupGiftController extends Notifier<CreateGroupGiftState> {
  CreateGroupGiftController(this.itemId);

  final String itemId;

  /// Minted once per screen, not per attempt: a failed create that actually
  /// landed must not claim the item twice when the user taps again.
  final String _idempotencyKey = newIdempotencyKey();

  @override
  CreateGroupGiftState build() => const CreateGroupGiftState();

  /// Seeds the goal from the item's price the first time the screen builds.
  /// Later calls are ignored so a rebuild cannot overwrite an edited goal.
  void primeGoal(int? itemPriceMinor) {
    if (state.goalAmountMinor != null || itemPriceMinor == null) return;
    state = state.copyWith(goalAmountMinor: itemPriceMinor);
  }

  void setGoal(int? amountMinor) =>
      state = state.copyWith(goalAmountMinor: amountMinor, clearError: true);

  void setMode(ContributionMode mode) => state = state.copyWith(mode: mode);

  void setCustomAmount(int? amountMinor) => state = amountMinor == null
      ? state.copyWith(clearCustomAmount: true)
      : state.copyWith(customAmountMinor: amountMinor);

  void setUpiId(String value) => state = state.copyWith(upiId: value);

  void setTitle(String value) =>
      state = state.copyWith(title: value, clearError: true);

  void setMessage(String value) => state = state.copyWith(message: value);

  Future<GroupGift?> submit() async {
    if (!state.canSubmit) return null;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final gift = await ref
          .read(groupGiftRepositoryProvider)
          .create(
            itemId,
            title: state.title.trim(),
            targetAmountMinor: state.goalAmountMinor,
            hostUpiId: state.upiId.trim(),
            contributionMode: state.mode,
            suggestedAmountsMinor: state.allSuggestedAmountsMinor,
            message: state.message.trim().isEmpty ? null : state.message.trim(),
            idempotencyKey: _idempotencyKey,
          );
      state = state.copyWith(busy: false, created: gift);
      return gift;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return null;
    }
  }

  String _message(ApiException e) => switch (e.code) {
    'ITEM_NOT_AVAILABLE' ||
    'ITEM_ALREADY_CLAIMED' => 'Someone else has already claimed this item.',
    'CANNOT_GIFT_OWN_ITEM' => 'You cannot start a group gift on your own item.',
    _ => e.message,
  };
}

final createGroupGiftProvider =
    NotifierProvider.family<
      CreateGroupGiftController,
      CreateGroupGiftState,
      String
    >(CreateGroupGiftController.new);
