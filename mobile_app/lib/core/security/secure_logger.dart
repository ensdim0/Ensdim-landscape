import 'package:flutter/foundation.dart';

/// Secure logger that prevents sensitive data leakage.
///
/// - In **release** mode: all logging is suppressed (no-op).
/// - In **debug** mode: logs are printed with sensitive fields redacted.
///
/// Never log passwords, tokens, or full email addresses.
abstract final class SecureLogger {
  /// Logs an informational message (debug only).
  static void info(String tag, String message) {
    if (kReleaseMode) return;
    debugPrint('[$tag] INFO: ${_redact(message)}');
  }

  /// Logs a warning (debug only).
  static void warning(String tag, String message) {
    if (kReleaseMode) return;
    debugPrint('[$tag] WARN: ${_redact(message)}');
  }

  /// Logs an error with optional exception (debug only).
  static void error(String tag, String message, [Object? exception]) {
    if (kReleaseMode) return;
    debugPrint('[$tag] ERROR: ${_redact(message)}');
    if (exception != null) {
      debugPrint('[$tag] Exception: ${exception.runtimeType}');
    }
  }

  /// Redacts common sensitive patterns from log strings.
  static String _redact(String input) {
    // Redact emails: show first 2 chars + domain
    String output = input.replaceAllMapped(
      RegExp(r'([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})'),
      (m) => '${m[1]!.substring(0, (m[1]!.length).clamp(0, 2))}***@${m[2]}',
    );

    // Redact JWT tokens
    output = output.replaceAll(
      RegExp(r'eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+'),
      '[REDACTED_TOKEN]',
    );

    // Redact password-like fields
    output = output.replaceAll(
      RegExp(r'password["\s:=]+[^\s,}"]+', caseSensitive: false),
      'password: [REDACTED]',
    );

    return output;
  }
}
