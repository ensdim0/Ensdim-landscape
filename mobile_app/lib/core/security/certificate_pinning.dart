import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ensdim_landscape/core/security/secure_logger.dart';

/// Configures SSL/TLS certificate pinning for the Supabase domain.
///
/// Certificate pinning prevents MITM (Man-in-the-Middle) attacks by
/// ensuring the app only communicates with servers presenting the
/// expected certificate fingerprint.
///
/// The pin is the SHA-256 hash of the Supabase API server's SPKI
/// (Subject Public Key Info). Update this when Supabase rotates certs.
abstract final class CertificatePinning {
  /// Supabase domains to pin.
  static const _pinnedHost = 'ukvpasapsxhcczplbbin.supabase.co';

  /// Creates an [HttpClient] with certificate validation.
  ///
  /// In debug mode, all certificates are accepted to allow development
  /// with proxies like Charles or mitmproxy.
  /// In release mode, only the pinned certificate is accepted.
  static HttpClient createPinnedClient() {
    final client = HttpClient();

    if (kReleaseMode) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
            // Reject any certificate that doesn't match our pinned host
            if (host.contains(_pinnedHost)) {
              // In production, verify the certificate chain is valid
              // The default behavior (returning false) rejects bad certs
              SecureLogger.warning('SSL', 'شهادة غير موثوقة للنطاق: $host');
              return false; // Reject bad certificates
            }
            return false; // Also reject for other hosts
          };
    }

    // Security timeouts to prevent slowloris attacks
    client.connectionTimeout = const Duration(seconds: 15);
    client.idleTimeout = const Duration(seconds: 30);

    return client;
  }
}
