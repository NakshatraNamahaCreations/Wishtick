import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wishtick_flutter/core/media/media_playback.dart';

/// Answers a fixed status for any request, standing in for the play endpoint.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.statusCode);

  final int statusCode;
  final requestedHeaders = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedHeaders.add(options.headers);
    return ResponseBody.fromString('', statusCode);
  }

  @override
  void close({bool force = false}) {}
}

/// A transport that always fails, the way a dead connection does.
class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'no route to host',
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(HttpClientAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  /// The distinction the whole thing exists for: a clip that is nearly ready
  /// must not read as a clip that is broken.
  test('409 means still encoding, not broken', () async {
    final result = await probePlayback(
      'https://api.test/media/abc/play',
      client: _dioWith(_StubAdapter(409)),
    );

    expect(result, PlaybackReadiness.processing);
  });

  test('a redirect is a ready answer — it is not followed', () async {
    final result = await probePlayback(
      'https://api.test/media/abc/play',
      client: _dioWith(_StubAdapter(302)),
    );

    expect(result, PlaybackReadiness.ready);
  });

  test('a plain 200 (an ordinary CDN file) is ready', () async {
    final result = await probePlayback(
      'https://cdn.test/users/1/memory_wish/abc.mp4',
      client: _dioWith(_StubAdapter(206)),
    );

    expect(result, PlaybackReadiness.ready);
  });

  test('404 and 403 are unavailable, so nothing retries them', () async {
    for (final code in [403, 404, 500]) {
      expect(
        await probePlayback('https://api.test/x', client: _dioWith(_StubAdapter(code))),
        PlaybackReadiness.unavailable,
        reason: 'status $code',
      );
    }
  });

  /// Retrying forever on a dead connection would spin a spinner that never
  /// resolves, which is worse than saying the video cannot be played.
  test('a transport failure is unavailable, not processing', () async {
    final result = await probePlayback(
      'https://api.test/media/abc/play',
      client: _dioWith(_FailingAdapter()),
    );

    expect(result, PlaybackReadiness.unavailable);
  });

  test('asks for one byte rather than the whole file', () async {
    final adapter = _StubAdapter(206);

    await probePlayback('https://cdn.test/big.mp4', client: _dioWith(adapter));

    expect(adapter.requestedHeaders.single['range'], 'bytes=0-0');
  });
}
