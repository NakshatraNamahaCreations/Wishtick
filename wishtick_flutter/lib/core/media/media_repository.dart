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
  reelWish('reel_wish');

  const MediaPurpose(this.wireValue);

  final String wireValue;
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
  });

  final String id;
  final String url;
  final String purpose;
  final String? contentType;
  final int? sizeBytes;

  factory MediaView.fromJson(Map<String, dynamic> json) => MediaView(
    id: json['id'] as String,
    url: json['url'] as String,
    purpose: json['purpose'] as String,
    contentType: json['contentType'] as String?,
    sizeBytes: json['sizeBytes'] as int?,
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

  Future<MediaView> uploadFile({
    required XFile file,
    required MediaPurpose purpose,
  }) async {
    final bytes = await file.readAsBytes();
    final contentType = file.mimeType ?? _guessContentType(file.name);

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

  /// Only consulted when the picker gave no mime type — which `file_picker`
  /// routinely does on Android for anything it did not open through the
  /// gallery.
  static String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.pdf')) return 'application/pdf';
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
