import 'package:dio/dio.dart';

/// A failure surfaced by the Wishtick API or the transport beneath it.
///
/// The backend returns
/// `{success: false, error: {code, message, details}, requestId, timestamp}`
/// and its own docs are explicit: **branch on [code], never on [message]**.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
    this.requestId,
  });

  final String code;
  final String message;
  final int? statusCode;
  final Object? details;
  final String? requestId;

  /// Transport-level codes, used when the server never answered.
  static const codeNetwork = 'NETWORK_ERROR';
  static const codeTimeout = 'TIMEOUT';
  static const codeCancelled = 'CANCELLED';
  static const codeUnknown = 'UNKNOWN_ERROR';

  /// Server codes the app branches on.
  static const codeUnauthorized = 'UNAUTHORIZED';
  static const codeValidationFailed = 'VALIDATION_FAILED';

  bool get isUnauthorized => statusCode == 401;
  bool get isNetworkFailure => code == codeNetwork || code == codeTimeout;

  factory ApiException.fromDioException(DioException e) {
    final response = e.response;
    final body = response?.data;

    if (body is Map && body['error'] is Map) {
      final error = body['error'] as Map;
      return ApiException(
        code: error['code']?.toString() ?? codeUnknown,
        message: error['message']?.toString() ?? 'Something went wrong.',
        statusCode: response?.statusCode,
        details: error['details'],
        requestId: body['requestId']?.toString(),
      );
    }

    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiException(
        code: codeTimeout,
        message: 'The request timed out. Please try again.',
      ),
      DioExceptionType.connectionError => const ApiException(
        code: codeNetwork,
        message: 'No internet connection.',
      ),
      DioExceptionType.cancel => const ApiException(
        code: codeCancelled,
        message: 'Request cancelled.',
      ),
      _ => ApiException(
        code: codeUnknown,
        message: e.message ?? 'Something went wrong.',
        statusCode: response?.statusCode,
      ),
    };
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
