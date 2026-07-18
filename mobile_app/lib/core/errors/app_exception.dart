/// Classification of application errors for consistent handling.
enum ErrorType {
  /// Input validation failure.
  validation,

  /// Authentication or authorization failure.
  unauthorized,

  /// Network connectivity issue.
  network,

  /// Server-side error.
  server,

  /// Unclassified error.
  unknown,
}

/// Structured application exception with type classification.
///
/// Used across all layers to provide consistent, typed error handling
/// without leaking infrastructure details to upper layers.
class AppException implements Exception {
  final String message;
  final ErrorType type;
  final dynamic originalError;

  const AppException(this.message, this.type, [this.originalError]);

  @override
  String toString() => 'AppException($type): $message';
}
