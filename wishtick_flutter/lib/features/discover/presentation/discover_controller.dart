import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/discover_repository.dart';
import '../domain/discover_feed.dart';

@immutable
class DiscoverState {
  const DiscoverState({this.feed, this.error, this.busy = false});

  /// Null while loading.
  final DiscoverFeed? feed;
  final String? error;
  final bool busy;

  DiscoverState copyWith({
    DiscoverFeed? feed,
    String? error,
    bool? busy,
    bool clearError = false,
  }) {
    return DiscoverState(
      feed: feed ?? this.feed,
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

class DiscoverController extends Notifier<DiscoverState> {
  @override
  DiscoverState build() => const DiscoverState();

  DiscoverRepository get _repo => ref.read(discoverRepositoryProvider);

  Future<void> ensureLoaded() async {
    if (state.feed != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final feed = await _repo.feed();
      state = state.copyWith(feed: feed, busy: false);
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
    }
  }

  static String _message(ApiException e) => switch (e.code) {
    ApiException.codeNetwork ||
    ApiException.codeTimeout => 'No connection. Check your network and retry.',
    _ => e.message,
  };
}

final discoverProvider = NotifierProvider<DiscoverController, DiscoverState>(
  DiscoverController.new,
);
