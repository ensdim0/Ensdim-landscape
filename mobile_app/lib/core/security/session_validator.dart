import 'dart:convert';

/// Validates session tokens to prevent token forgery and replay attacks.
///
/// Checks JWT structure (without verifying signature — that's server-side)
/// and validates expiration times client-side as an early rejection layer.
abstract final class SessionValidator {
  /// Checks if a JWT token has a valid structure and is not expired.
  static bool isTokenValid(String? token) {
    if (token == null || token.isEmpty) return false;

    final parts = token.split('.');
    if (parts.length != 3) return false;

    try {
      final payload = _decodePayload(parts[1]);
      if (payload == null) return false;

      final exp = payload['exp'] as int?;
      if (exp == null) return false;

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isBefore(expiry);
    } catch (_) {
      return false;
    }
  }

  /// Returns the remaining token lifetime, or null for invalid tokens.
  static Duration? tokenTimeToLive(String? token) {
    if (token == null || token.isEmpty) return null;

    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload = _decodePayload(parts[1]);
      if (payload == null) return null;

      final exp = payload['exp'] as int?;
      if (exp == null) return null;

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final remaining = expiry.difference(DateTime.now());
      return remaining.isNegative ? null : remaining;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _decodePayload(String payload) {
    try {
      // JWT uses base64url encoding without padding
      String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      switch (normalized.length % 4) {
        case 2:
          normalized += '==';
        case 3:
          normalized += '=';
      }
      final decoded = utf8.decode(base64Decode(normalized));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) return json;
      return null;
    } catch (_) {
      return null;
    }
  }
}
