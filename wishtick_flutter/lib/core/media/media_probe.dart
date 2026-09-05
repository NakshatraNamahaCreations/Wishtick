import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// How long a clip on this device runs, without uploading it.
///
/// Opens the file with the same decoder that will eventually play it, reads the
/// duration off the initialised controller, and disposes it. Cheap: no frames
/// are rendered and no bytes leave the phone.
///
/// Returns **null** when the file cannot be opened or reports no duration —
/// a codec the device cannot decode, a stream with no length in its header, a
/// path that has gone away. Null means "unknown", never "zero": a caller
/// checking a duration limit must let an unknown through, because refusing on
/// a failed probe would block clips that are perfectly fine on a device whose
/// decoder happens to be fussy. The server measures it again after the encode,
/// which is what actually holds the line.
Future<Duration?> probeMediaDuration(String path) async {
  final controller = VideoPlayerController.file(File(path));
  try {
    await controller.initialize();
    final length = controller.value.duration;
    return length > Duration.zero ? length : null;
  } catch (_) {
    return null;
  } finally {
    // Always — an initialised controller holds a platform texture, and leaking
    // one per pick would exhaust the decoder after a handful of attempts.
    await controller.dispose();
  }
}

/// Measures a local clip. See [probeMediaDuration].
typedef MediaDurationProbe = Future<Duration?> Function(String path);

/// The probe a compose screen uses before accepting a clip.
///
/// Behind a provider because the real one opens a platform decoder, which no
/// widget test has — and the duration check is exactly the behaviour worth
/// testing. Override it to hand a screen a clip of any length.
final mediaDurationProbeProvider = Provider<MediaDurationProbe>(
  (ref) => probeMediaDuration,
);
