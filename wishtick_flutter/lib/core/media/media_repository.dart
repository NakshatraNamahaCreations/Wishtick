import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';

/// What an uploaded image is for — the backend keys its size/type limits and
/// retention off this, and rejects a `mediaId` used somewhere its `purpose`
/// doesn't match (`MEDIA_TYPE_NOT_ALLOWED`).
enum MediaPurpose {
  profilePhoto('profile_photo'),
  eventCover('event_cover'),
  wishlistItem('wishlist_item'),
  wishlistCover('wishlist_cover'),

  /// A host's own invitation artwork (`2248:70`). The only purpose that admits
  /// GIF, MP4 and PDF as well as still images.
  eventInvite('event_invite'),

  /// A memory capsule's cover (`4104:1539`).
  memoryCover('memory_cover'),

  /// A contributed wish's photo, video or voice note. Takes audio as well as
  /// stills and video.
  memoryWish('memory_wish'),

  /// A thank-you note's photo, voice note or video (`2015:271`, `2015:382`).
  /// Same envelope as [memoryWish] — one person recording one short reply —
  /// but its own purpose so retention and revocation stay separable.
  thankYou('thank_you'),
  reelWish('reel_wish');

  const MediaPurpose(this.wireValue);

  final String wireValue;
}

/// Where an upload has got to on the server.
enum MediaStatus {
  pending('pending'),

  /// Video only: the bytes are stored and a transcoder is working on them.
  /// Attachable — the URL is stable — but not yet playable.
  processing('processing'),
  ready('ready'),

  /// Transcoding failed. Terminal; there is no source left to retry from.
  failed('failed'),
  orphaned('orphaned');

  const MediaStatus(this.wireValue);

  final String wireValue;

  static MediaStatus fromWire(String? value) =>
      MediaStatus.values.firstWhere((s) => s.wireValue == value, orElse: () => ready);
}

/// A confirmed, ready-to-use upload — `id` is what a feature DTO stores
/// (`coverMediaId`, `mediaIds`), `url` is what the app displays immediately
/// without waiting for a fresh fetch of the parent resource.
class MediaView {
  const MediaView({
    required this.id,
    required this.url,
    required this.purpose,
    required this.contentType,
    required this.sizeBytes,
    this.status = MediaStatus.ready,
    this.durationSeconds,
  });

  final String id;

  /// Stable for the life of the media. For a transcoded clip this is a link
  /// the API owns, which redirects to a freshly signed playback URL — signed
  /// URLs expire, and this one gets copied into wishlists and memories.
  final String url;
  final String purpose;
  final String? contentType;
  final int? sizeBytes;
  final MediaStatus status;

  /// Set once a transcoder has measured the clip. Null for stills.
  final int? durationSeconds;

  /// Whether a player can open [url] right now.
  bool get isPlayable => status == MediaStatus.ready;

  factory MediaView.fromJson(Map<String, dynamic> json) => MediaView(
    id: json['id'] as String,
    url: json['url'] as String,
    purpose: json['purpose'] as String,
    contentType: json['contentType'] as String?,
    sizeBytes: json['sizeBytes'] as int?,
    status: MediaStatus.fromWire(json['status'] as String?),
    durationSeconds: json['durationSeconds'] as int?,
  );
}

/// Uploads an image via the backend's three-step handshake — `upload-url`
/// mints a ticket and a destination, the bytes go straight to that
/// destination (never through this API), then `confirm` turns the ticket into
/// a real, referenceable [MediaView].
///
/// One repository for every feature that uploads an image (wishlist covers
/// today; profile photos and event covers were deferred but would plug into
/// the same [uploadFile] call), rather than one per feature.
class MediaRepository {
  MediaRepository(this._api, this._transferDio);

  final ApiClient _api;

  /// A bare Dio with no auth interceptor — the upload destination is not
  /// necessarily this API (it may be a storage provider's own signed URL),
  /// so it must not carry this app's bearer token or retry/refresh logic.
  final Dio _transferDio;

  /// Re-reads one media, asking the server to refresh an in-flight transcode.
  ///
  /// Poll this while [MediaView.status] is `processing` to learn when a clip
  /// becomes playable — the server checks the transcoder on each call, so the
  /// answer is never stale.
  Future<MediaView> getMedia(String mediaId) async {
    final json = await _api.get<Map<String, dynamic>>('/media/$mediaId');
    return MediaView.fromJson(json);
  }

  Future<MediaView> uploadFile({
    required XFile file,
    required MediaPurpose purpose,
    String? fileName,
  }) async {
    final bytes = await file.readAsBytes();
    final contentType = contentTypeFor(file, fileName: fileName);

    final ticket = await _api.post<Map<String, dynamic>>(
      '/media/upload-url',
      body: {
        'purpose': purpose.wireValue,
        'contentType': contentType,
        'sizeBytes': bytes.length,
      },
    );

    final uploadUrl = ticket['uploadUrl'] as String;
    final mediaId = ticket['mediaId'] as String;
    final requiredHeaders = (ticket['requiredHeaders'] as Map?)?.map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );

    try {
      await _transferDio.put<void>(
        uploadUrl,
        data: bytes,
        options: Options(
          headers: {'Content-Type': contentType, ...?requiredHeaders},
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }

    final confirmed = await _api.post<Map<String, dynamic>>(
      '/media/confirm',
      body: {'mediaId': mediaId},
    );
    return MediaView.fromJson(confirmed);
  }

  /// What to tell the server this file is.
  ///
  /// The picker's own mime type when it gave one; otherwise a guess from the
  /// name — `file_picker` supplies no type on Android for anything it did not
  /// open through the gallery, which is most of the time.
  ///
  /// [fileName] exists because **`XFile.fromData` ignores its `name`** on
  /// io: the constructor documents it as "only to match the web version", and
  /// `.name` falls back to the basename of an empty path. Any caller building
  /// an XFile from bytes must pass the real filename here, or every upload it
  /// makes is guessed from nothing.
  ///
  /// Every extension the app can upload must be in the table below. A miss
  /// falls through to `image/jpeg` and the server believes it: a voice note
  /// stored as a JPEG uploads happily, gets a `.jpg` storage key, and then will
  /// not play.
  static String contentTypeFor(XFile file, {String? fileName}) =>
      file.mimeType ?? _guessFromName(fileName ?? file.name);

  static String _guessFromName(String fileName) {
    const byExtension = {
      '.png': 'image/png',
      '.webp': 'image/webp',
      '.heic': 'image/heic',
      '.gif': 'image/gif',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.mp4': 'video/mp4',
      '.mov': 'video/quicktime',
      '.mp3': 'audio/mpeg',
      '.m4a': 'audio/mp4',
      '.aac': 'audio/aac',
      '.wav': 'audio/wav',
      '.pdf': 'application/pdf',
    };
    final lower = fileName.toLowerCase();
    for (final entry in byExtension.entries) {
      if (lower.endsWith(entry.key)) return entry.value;
    }
    return 'image/jpeg';
  }
}

/// A Dio with no interceptors, dedicated to raw byte transfers to whatever
/// destination `upload-url` names — separate from [dioProvider] so an upload
/// destination outside this API never sees this app's auth headers.
final _transferDioProvider = Provider<Dio>((ref) => Dio());

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(
    ref.watch(apiClientProvider),
    ref.watch(_transferDioProvider),
  );
});
