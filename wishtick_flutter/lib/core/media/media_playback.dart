import 'package:dio/dio.dart';

/// Whether a stored media link can be played right now.
enum PlaybackReadiness {
  /// Play it.
  ready,

  /// A video the transcoder has not finished with. Temporary — worth waiting
  /// for and worth saying so, which is the whole reason this enum exists.
  processing,

  /// Gone, refused, or broken. Not worth retrying.
  unavailable,
}

/// Asks whether a media URL is playable yet, without downloading it.
///
/// A transcoded clip is stored as a stable `/media/:id/play` link that
/// redirects to a freshly signed, expiring URL. While the encode is still
/// running that endpoint answers **409**, and a player handed it simply fails —
/// which on screen is indistinguishable from a corrupt file. So the same
/// upload reads as "this video is broken" for the minute or two after it was
/// recorded, which is exactly when someone is most likely to be looking at it.
///
/// Redirects are deliberately not followed: the 302 itself is the answer, and
/// following it would fetch the manifest for nothing.
Future<PlaybackReadiness> probePlayback(String url, {Dio? client}) async {
  final dio = client ?? Dio();
  try {
    final response = await dio.get<void>(
      url,
      options: Options(
        followRedirects: false,
        // The status is the payload here; an exception would throw away the
        // very distinction being drawn.
        validateStatus: (_) => true,
        // A plain CDN file answers a range request cheaply, and a redirect
        // answers before any body at all.
        headers: {'range': 'bytes=0-0'},
      ),
    );

    final status = response.statusCode ?? 0;
    if (status == 409) return PlaybackReadiness.processing;
    if (status >= 200 && status < 400) return PlaybackReadiness.ready;
    return PlaybackReadiness.unavailable;
  } on DioException {
    // No network, a timeout, a DNS failure. Treated as unavailable rather than
    // processing: retrying forever on a dead connection would spin a spinner
    // that never resolves.
    return PlaybackReadiness.unavailable;
  }
}
