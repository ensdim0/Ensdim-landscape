/// Brute-force protection via in-memory rate limiting.
///
/// Tracks failed login attempts per email and locks accounts temporarily
/// after exceeding the threshold. Resets on successful login.
///
/// This is a client-side supplement; the server should also enforce
/// rate limiting via Supabase's built-in GoTrue rate limiter.
class LoginRateLimiter {
  /// Max allowed consecutive failed attempts before lockout.
  static const int maxAttempts = 5;

  /// Duration of the lockout period.
  static const Duration lockoutDuration = Duration(minutes: 5);

  /// Tracks attempts per email.
  final Map<String, _AttemptRecord> _attempts = {};

  /// Returns `true` if the given email is currently locked out.
  bool isLockedOut(String email) {
    final key = email.toLowerCase().trim();
    final record = _attempts[key];
    if (record == null) return false;

    if (record.lockedUntil != null &&
        DateTime.now().isBefore(record.lockedUntil!)) {
      return true;
    }

    // Lockout expired — reset
    if (record.lockedUntil != null &&
        DateTime.now().isAfter(record.lockedUntil!)) {
      _attempts.remove(key);
      return false;
    }

    return false;
  }

  /// Returns the remaining lockout time, or `null` if not locked.
  Duration? remainingLockout(String email) {
    final key = email.toLowerCase().trim();
    final record = _attempts[key];
    if (record?.lockedUntil == null) return null;

    final remaining = record!.lockedUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Records a failed login attempt. Returns `true` if now locked out.
  bool recordFailedAttempt(String email) {
    final key = email.toLowerCase().trim();
    final record = _attempts[key] ?? _AttemptRecord();

    record.failedCount++;

    if (record.failedCount >= maxAttempts) {
      record.lockedUntil = DateTime.now().add(lockoutDuration);
    }

    _attempts[key] = record;
    return record.lockedUntil != null;
  }

  /// Resets tracking for an email after a successful login.
  void resetAttempts(String email) {
    _attempts.remove(email.toLowerCase().trim());
  }
}

class _AttemptRecord {
  int failedCount = 0;
  DateTime? lockedUntil;
}
