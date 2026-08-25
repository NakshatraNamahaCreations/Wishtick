import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/wishmates_repository.dart';
import '../domain/wishmate.dart';
import 'wishmates_providers.dart';

/// What a graph mutation came back with.
///
/// A record rather than a thrown exception because every caller is a button in
/// a list row: it awaits, and then either repaints or shows a message. Making
/// each of those a try/catch would put the same four lines in five screens.
typedef WishmateResult = ({WishmateRelationship? relationship, String? error});

/// Every mutation the graph screens perform, in one place.
///
/// Each one is the same three steps — call, refetch the graph, report a
/// failure — and five screens doing that inline is five chances to forget the
/// refetch and leave a request sitting in a list it has just left.
/// [invalidateWishmateGraph] is why the refetch is wholesale: accepting one
/// request changes the list, both tabs, the banner and the suggestions.
class WishmateActions {
  const WishmateActions(this._ref);

  final Ref _ref;

  WishmatesRepository get _repo => _ref.read(wishmatesRepositoryProvider);

  /// Sends a request, or accepts one already waiting — the server decides
  /// which, so the resulting relationship is what comes back rather than a
  /// value the caller assumed.
  Future<WishmateResult> request(String userId) =>
      _run(() => _repo.request(userId));

  Future<WishmateResult> accept(String linkId) =>
      _run(() => _repo.accept(linkId));

  /// Resolves to [WishmateRelationship.none] — indistinguishable from never
  /// having been asked, which is exactly what the sender will go on seeing.
  Future<WishmateResult> decline(String linkId) =>
      _run(() => _repo.decline(linkId));

  /// The Sent tab's Delete.
  Future<WishmateResult> withdraw(String linkId) =>
      _run(() async => _repo.withdraw(linkId).then((_) => null));

  Future<WishmateResult> remove(String userId) =>
      _run(() async => _repo.remove(userId).then((_) => null));

  Future<WishmateResult> _run(
    Future<WishmateRelationship?> Function() call,
  ) async {
    try {
      final relationship = await call();
      // The provider-side twin of [invalidateWishmateGraph]; see the note on
      // [wishmateGraphProviders] for why there are two.
      for (final provider in wishmateGraphProviders) {
        _ref.invalidate(provider);
      }
      return (relationship: relationship, error: null);
    } on ApiException catch (e) {
      return (relationship: null, error: e.message);
    }
  }
}

final wishmateActionsProvider = Provider<WishmateActions>(WishmateActions.new);

/// Shows [WishmateResult.error] if there was one. Returns whether it succeeded,
/// so a caller can go on to navigate only when it did.
bool reportWishmateResult(BuildContext context, WishmateResult result) {
  final error = result.error;
  if (error == null) return true;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  return false;
}
