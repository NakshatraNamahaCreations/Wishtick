import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/invite_repository.dart';
import '../domain/public_invite.dart';

@immutable
class InviteState {
  const InviteState({this.invite, this.error, this.busy = false});

  final PublicInvite? invite;
  final String? error;
  final bool busy;

  InviteState copyWith({
    PublicInvite? invite,
    String? error,
    bool? busy,
    bool clearError = false,
  }) => InviteState(
    invite: invite ?? this.invite,
    error: clearError ? null : (error ?? this.error),
    busy: busy ?? this.busy,
  );
}

/// Owns one invite, keyed by its token.
class InviteController extends Notifier<InviteState> {
  InviteController(this.token);

  final String token;

  @override
  InviteState build() => const InviteState();

  InviteRepository get _repo => ref.read(inviteRepositoryProvider);

  Future<void> ensureLoaded() async {
    if (state.invite != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      state = InviteState(invite: await _repo.getByToken(token));
    } on ApiException catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.code == 'INVITE_TOKEN_INVALID'
            ? 'This invite link is no longer valid.'
            : e.message,
      );
    }
  }

  /// Answering returns the invite freshly resolved, which is how a wishlist the
  /// host attached can appear only after a yes — so the response replaces the
  /// whole state rather than patching the RSVP field.
  Future<bool> respond(RsvpResponse response, {int? plusOnes}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final invite = await _repo.rsvp(
        token,
        response: response,
        plusOnes: plusOnes,
      );
      state = InviteState(invite: invite);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    }
  }

  static String _message(ApiException e) => switch (e.code) {
    'EVENT_CANCELLED' => 'This event has been cancelled.',
    'EVENT_NOT_PUBLISHED' => 'This invite is not active yet.',
    _ => e.message,
  };
}

final inviteProvider =
    NotifierProvider.family<InviteController, InviteState, String>(
      InviteController.new,
    );
