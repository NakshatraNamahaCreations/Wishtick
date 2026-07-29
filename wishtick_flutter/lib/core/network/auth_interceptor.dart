import 'dart:async';

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_storage.dart';

/// Attaches the bearer token and transparently rotates it on a 401.
///
/// Refreshes are funnelled through a single [Completer] so a burst of parallel
/// requests failing at once produces one `POST /auth/refresh`, not one per
/// request — the backend rotates refresh tokens, so racing calls would
/// invalidate each other and log the user out.
class AuthInterceptor extends Interceptor {
  /// [refreshClient] must be a bare Dio *without* this interceptor attached,
  /// so refreshing cannot recurse. [onSessionExpired] runs when the refresh
  /// token is gone or rejected, and should sign the user out.
  AuthInterceptor(this._tokens, this._refreshClient, this._onSessionExpired);

  final TokenStorage _tokens;
  final Dio _refreshClient;
  final Future<void> Function() _onSessionExpired;

  Completer<String?>? _inFlightRefresh;

  /// Endpoints that must never carry a stale bearer token or trigger a retry.
  static const _authPaths = {
    '/auth/login',
    '/auth/signup',
    '/auth/refresh',
    '/auth/password/forgot',
    '/auth/password/reset',
  };

  bool _isAuthPath(String path) => _authPaths.any(path.contains);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthPath(options.path)) {
      final token = await _tokens.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final isRetryable =
        response?.statusCode == 401 &&
        !_isAuthPath(err.requestOptions.path) &&
        err.requestOptions.extra['retried'] != true;

    if (!isRetryable) {
      return handler.next(err);
    }

    final newToken = await _refreshToken();
    if (newToken == null) {
      return handler.next(err);
    }

    try {
      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newToken'
        ..extra['retried'] = true;
      final retried = await _refreshClient.fetch<dynamic>(options);
      return handler.resolve(retried);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<String?> _refreshToken() {
    final inFlight = _inFlightRefresh;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<String?>();
    _inFlightRefresh = completer;

    unawaited(
      _performRefresh()
          .then((token) {
            _inFlightRefresh = null;
            completer.complete(token);
          })
          .catchError((Object _) {
            _inFlightRefresh = null;
            completer.complete(null);
          }),
    );

    return completer.future;
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) {
      await _onSessionExpired();
      return null;
    }

    try {
      final response = await _refreshClient.post<Map<String, dynamic>>(
        '${ApiConfig.baseUrl}/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) {
        await _onSessionExpired();
        return null;
      }
      final tokens = AuthTokens.fromJson(data);
      await _tokens.save(tokens);
      return tokens.accessToken;
    } on DioException {
      // The refresh token is spent or revoked — the session is over.
      await _onSessionExpired();
      return null;
    }
  }
}
