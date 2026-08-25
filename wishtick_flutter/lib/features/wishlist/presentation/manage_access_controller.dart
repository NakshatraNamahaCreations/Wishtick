import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/wishlist_repository.dart';
import '../domain/wishlist_participant.dart';

@immutable
class ManageAccessState {
  const ManageAccessState({this.participants, this.error, this.busy = false});

  /// Null while the first load is in flight; empty means nobody has access.
  final List<WishlistParticipant>? participants;

  /// The last failure, in the server's own words — it writes messages a person
  /// can read ("This person already has access to the wishlist").
  final String? error;

  /// An invite or a revoke is in flight.
  final bool busy;

  ManageAccessState copyWith({
    List<WishlistParticipant>? participants,
    String? error,
    bool? busy,
    bool clearError = false,
  }) => ManageAccessState(
    participants: participants ?? this.participants,
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
  );
}

/// Owns one wishlist's guest list — who can open it, and adding or removing
/// them.
///
/// Scoped to a wishlist id, like [wishlistDetailProvider], so opening two
/// lists' access screens in a session does not have them share state.
class ManageAccessController extends Notifier<ManageAccessState> {
  ManageAccessController(this.arg);

  /// The wishlist id this instance is scoped to.
  final String arg;

  @override
  ManageAccessState build() => const ManageAccessState();

  WishlistRepository get _repo => ref.read(wishlistRepositoryProvider);

  /// Loads the list once. Safe to call from `initState` on every rebuild.
  Future<void> ensureLoaded() async {
    if (state.participants != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final people = await _repo.listParticipants(arg);
      state = state.copyWith(participants: people, clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  /// Invites by email. Returns false and leaves [ManageAccessState.error] set
  /// when the server refuses — a duplicate, the owner's own address, or an
  /// identifier it will not accept.
  Future<bool> inviteByEmail(
    String email, {
    ParticipantRole role = ParticipantRole.viewer,
  }) async {
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final added = await _repo.addParticipant(
        arg,
        inviteEmail: trimmed,
        role: role,
      );
      state = state.copyWith(
        participants: [...?state.participants, added],
        busy: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, busy: false);
      return false;
    }
  }

  /// Removes someone. The row goes immediately on success rather than after a
  /// refetch — the server has already committed, and a second round trip would
  /// only make the tap feel slow.
  Future<bool> revoke(String participantId) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repo.revokeParticipant(arg, participantId);
      state = state.copyWith(
        participants: state.participants
            ?.where((p) => p.id != participantId)
            .toList(),
        busy: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message, busy: false);
      return false;
    }
  }
}

final manageAccessProvider =
    NotifierProvider.family<ManageAccessController, ManageAccessState, String>(
      ManageAccessController.new,
    );
