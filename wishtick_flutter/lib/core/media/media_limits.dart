import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'media_repository.dart';

/// What may be uploaded for one purpose.
class PurposeLimit {
  const PurposeLimit({
    required this.maxBytes,
    required this.mimeTypes,
    this.maxDurationSeconds,
  });

  final int maxBytes;
  final List<String> mimeTypes;

  /// How long a clip may run, or null where nothing caps it.
  ///
  /// Independent of [maxBytes]: a well-compressed five-minute video can slip
  /// under the size cap, and fifteen seconds off a modern phone can sail past
  /// it. Neither limit implies the other, so both are checked.
  final int? maxDurationSeconds;

  /// The cap as the screen should say it — "10 MB", not "10485760 bytes".
  ///
  /// Whole megabytes, floored. Rounding up would print a number the server
  /// refuses; a fraction ("9.5 MB") reads as precision nobody needs when the
  /// question is only ever "is this clip too big?".
  String get label => '${maxBytes ~/ (1024 * 1024)} MB';

  /// The duration cap as the screen should say it — "20s". Null when uncapped.
  String? get durationLabel =>
      maxDurationSeconds == null ? null : '${maxDurationSeconds}s';

  /// Whether a file of [sizeBytes] would be accepted.
  bool accepts(int sizeBytes) => sizeBytes <= maxBytes;

  /// Whether a clip of this length would be accepted.
  ///
  /// Compared in milliseconds against a whole-second cap, so a clip the picker
  /// reports as 20.4s is refused against a 20s limit — the server measures the
  /// same clip and rounds the same way, and an app that let it through would
  /// only be handing the user a failure further down the line.
  bool acceptsDuration(Duration length) {
    final max = maxDurationSeconds;
    return max == null || length.inMilliseconds <= max * 1000;
  }
}

/// The server's upload rules, per purpose.
///
/// Fetched rather than hardcoded because the effective cap is
/// `min(per-purpose rule, MEDIA_MAX_BYTES)` and the second half is deployment
/// configuration. The policy file says 50 MB for a memory wish; a deployment
/// with the default global cap enforces 10. An app that guessed from the first
/// number would tell someone their video is fine and then fail the upload —
/// which is exactly the bug this exists to stop.
class MediaLimits {
  const MediaLimits(this._byPurpose);

  final Map<String, PurposeLimit> _byPurpose;

  /// What applies to [purpose].
  ///
  /// Falls back to the global default for a purpose the server did not name,
  /// which can only happen against an older API than this build expects. A
  /// conservative number is the right guess there: too low merely asks for a
  /// smaller file, too high promises an upload that will fail.
  PurposeLimit forPurpose(MediaPurpose purpose) =>
      _byPurpose[purpose.wireValue] ?? _fallbackLimit;

  factory MediaLimits.fromJson(Map<String, dynamic> json) => MediaLimits({
    for (final entry in json.entries)
      if (entry.value case final Map<String, dynamic> rule)
        entry.key: PurposeLimit(
          maxBytes: (rule['maxBytes'] as num).toInt(),
          maxDurationSeconds: (rule['maxDurationSeconds'] as num?)?.toInt(),
          mimeTypes: ((rule['mimeTypes'] as List?) ?? const [])
              .map((t) => t.toString())
              .toList(),
        ),
  });

  /// What every screen uses until the real limits arrive, and if they never do.
  ///
  /// 10 MB is `MEDIA_MAX_BYTES`'s own default, so it is the cap on a
  /// stock deployment for every purpose whose rule is roomier than it — which
  /// is all of the ones that take video.
  static const fallback = MediaLimits({});

  /// No duration cap in the fallback: guessing one would refuse clips the
  /// server would have taken. The size cap is the safe guess because being
  /// wrong there only asks for a smaller file; inventing a 20-second ceiling
  /// against an API that allows a minute would block real wishes outright.
  static const _fallbackLimit = PurposeLimit(
    maxBytes: 10 * 1024 * 1024,
    mimeTypes: [],
  );
}

/// The upload limits, fetched once.
///
/// Read it through [mediaLimitsOr] rather than awaiting it: no screen should
/// hold up a picker for this, and a conservative default is a better answer
/// than a spinner.
final mediaLimitsProvider = FutureProvider<MediaLimits>((ref) async {
  final json = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/media/limits');
  return MediaLimits.fromJson(json);
});

/// The fetched limits if they have arrived, the safe defaults if not.
MediaLimits mediaLimitsOr(WidgetRef ref) =>
    ref.watch(mediaLimitsProvider).value ?? MediaLimits.fallback;
