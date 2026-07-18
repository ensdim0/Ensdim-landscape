import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility for sanitizing user input against injection and XSS attacks.
///
/// All user-facing input should pass through these methods before
/// being sent to the server or displayed in the UI.
abstract final class InputSanitizer {
  /// Script tags, event handlers, and JS execution patterns (XSS).
  static final _xssPatterns = RegExp(
    r'(<script|javascript\s*:|on\w+\s*=|eval\s*\(|document\.(cookie|write|location)|window\.(location|open))',
    caseSensitive: false,
  );

  /// SQL injection patterns — multi-keyword sequences, not isolated words.
  static final _sqlPatterns = RegExp(
    r"(('\s*(OR|AND)\s*')|(--.+)|(/\*.*\*/)|;\s*(DROP|DELETE|UPDATE|INSERT|ALTER|EXEC|TRUNCATE)\b|(UNION\s+(ALL\s+)?SELECT))",
    caseSensitive: false,
  );

  /// Sanitizes a general text input by removing dangerous patterns.
  static String sanitizeText(String input) {
    String cleaned = input.trim();
    cleaned = cleaned.replaceAll(_xssPatterns, '');
    cleaned = cleaned.replaceAll(_sqlPatterns, '');
    return cleaned;
  }

  /// Converts Arabic numerals to English numerals.
  static String _convertArabicToEnglishNumbers(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < arabic.length; i++) {
      result = result.replaceAll(arabic[i], english[i]);
    }
    return result;
  }

  /// Sanitizes email or phone input.
  static String sanitizeEmail(String email) {
    String normalized = _convertArabicToEnglishNumbers(email.trim());
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9@._+-]'), '');
  }

  /// Sanitizes a login identifier that may be either an email or a phone number.
  static String sanitizeLoginIdentifier(String identifier) {
    String normalized = _convertArabicToEnglishNumbers(
      identifier.trim().toLowerCase(),
    );
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9@._+-]'), '');
  }

  /// Checks whether a string contains injection/XSS attack patterns.
  ///
  /// This targets real attack signatures (script injection, SQL sequences)
  /// rather than individual special characters, which are legitimate in
  /// passwords and emails.
  static bool containsMaliciousContent(String input) {
    return _xssPatterns.hasMatch(input) || _sqlPatterns.hasMatch(input);
  }

  /// Hashes a string using SHA-256 (e.g. for logging identifiers safely).
  static String hashForLog(String value) {
    final bytes = utf8.encode(value);
    return sha256.convert(bytes).toString().substring(0, 12);
  }
}
