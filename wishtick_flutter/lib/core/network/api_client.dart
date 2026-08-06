import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'token_storage.dart';

/// Thin wrapper over Dio that unwraps the backend's success envelope
/// (`{success, data, requestId, timestamp}`) and converts every failure into an
/// [ApiException], so feature code never imports Dio.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Dio get raw => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) {
    return _send<T>(
      () => _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      ),
    );
  }

  /// [headers] is per-request rather than baked into the Dio instance because
  /// the only current use is `Idempotency-Key`, which must differ per call —
  /// a shared header would make every retry look like a different request.
  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return _send<T>(
      () => _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: cancelToken,
        options: headers == null ? null : Options(headers: headers),
      ),
    );
  }

  Future<T> patch<T>(String path, {Object? body, CancelToken? cancelToken}) {
    return _send<T>(
      () => _dio.patch<Map<String, dynamic>>(
        path,
        data: body,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> put<T>(String path, {Object? body, CancelToken? cancelToken}) {
    return _send<T>(
      () => _dio.put<Map<String, dynamic>>(
        path,
        data: body,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> delete<T>(String path, {Object? body, CancelToken? cancelToken}) {
    return _send<T>(
      () => _dio.delete<Map<String, dynamic>>(
        path,
        data: body,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<T> _send<T>(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      final body = response.data;
      if (body == null) {
        if (null is T) return null as T;
        throw const ApiException(
          code: ApiException.codeUnknown,
          message: 'Empty response from server.',
        );
      }
      // Every success passes through ResponseInterceptor on the backend, so the
      // payload always sits under `data`.
      return body['data'] as T;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// A Dio with no auth interceptor — used for token refresh and retries so the
/// interceptor cannot recurse into itself.
final _refreshDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
    ),
  );
});

/// Fired when the refresh token is rejected.
///
/// The default only clears the stored tokens. `main()` overrides it with
/// `sessionExpiryOverride` so the session controller also flips to signed-out
/// and the router redirects — done as an override to keep this layer free of
/// feature imports.
final onSessionExpiredProvider = Provider<Future<void> Function()>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  return tokens.clear;
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
      // Let the interceptor see 4xx bodies instead of throwing before it runs.
      validateStatus: (status) => status != null && status < 400,
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      ref.watch(tokenStorageProvider),
      ref.watch(_refreshDioProvider),
      () => ref.read(onSessionExpiredProvider)(),
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => developer.log(o.toString(), name: 'api'),
      ),
    );
  }

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
