import 'package:ensdim_landscape/core/errors/app_exception.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/security/input_sanitizer.dart';
import 'package:ensdim_landscape/core/security/login_rate_limiter.dart';
import 'package:ensdim_landscape/core/security/secure_logger.dart';
import 'package:ensdim_landscape/core/types/result.dart';
import 'package:ensdim_landscape/domain/entities/app_user.dart';
import 'package:ensdim_landscape/domain/repositories/auth_repository.dart';

/// Handles user login with input validation, rate limiting, and error mapping.
///
/// Security features:
/// - Input sanitization against injection/XSS
/// - Rate limiting (5 attempts per 5 minutes)
/// - Secure logging (no passwords/tokens in logs)
/// - Typed error results for safe UI handling
class LoginUseCase {
  final AuthRepository _authRepository;
  final LoginRateLimiter _rateLimiter;

  LoginUseCase(this._authRepository, this._rateLimiter);

  /// Validates credentials and attempts login.
  Future<Result<AppUser>> call(String email, String password) async {
    final sanitizedIdentifier = InputSanitizer.sanitizeLoginIdentifier(email);
    final trimmedIdentifier = sanitizedIdentifier.trim();

    // --- Input Validation ---
    if (trimmedIdentifier.isEmpty || password.isEmpty) {
      return Failure(
        AppException(
          AppLocalizations.current.tr('emailAndPasswordRequired'),
          ErrorType.validation,
        ),
      );
    }

    if (!_isValidIdentifier(trimmedIdentifier)) {
      return Failure(
        AppException(
          AppLocalizations.current.tr('invalidEmailFormat'),
          ErrorType.validation,
        ),
      );
    }

    if (password.length < 6) {
      return Failure(
        AppException(
          AppLocalizations.current.tr('passwordTooShort'),
          ErrorType.validation,
        ),
      );
    }

    // --- Injection Detection (email only; password is sent encrypted) ---
    if (InputSanitizer.containsMaliciousContent(trimmedIdentifier)) {
      SecureLogger.warning(
        'Auth',
        'محاولة حقن مكتشفة من: ${InputSanitizer.hashForLog(trimmedIdentifier)}',
      );
      return Failure(
        AppException(
          AppLocalizations.current.tr('maliciousEmailFormat'),
          ErrorType.validation,
        ),
      );
    }

    // --- Rate Limiting ---
    if (_rateLimiter.isLockedOut(trimmedIdentifier)) {
      final remaining = _rateLimiter.remainingLockout(trimmedIdentifier);
      final minutes = (remaining?.inSeconds ?? 300) ~/ 60 + 1;
      SecureLogger.warning(
        'Auth',
        'حساب مقفل: ${InputSanitizer.hashForLog(trimmedIdentifier)}',
      );
      return Failure(
        AppException(
          AppLocalizations.current.trArgs(
            'accountLockedOut',
            minutes.toString(),
          ),
          ErrorType.unauthorized,
        ),
      );
    }

    // --- Execute ---
    try {
      final user = await _authRepository.login(trimmedIdentifier, password);
      _rateLimiter.resetAttempts(trimmedIdentifier);
      SecureLogger.info(
        'Auth',
        'تسجيل دخول ناجح: ${InputSanitizer.hashForLog(trimmedIdentifier)}',
      );
      return Success(user);
    } on AppException catch (e) {
      _rateLimiter.recordFailedAttempt(trimmedIdentifier);
      SecureLogger.warning(
        'Auth',
        'فشل تسجيل دخول: ${InputSanitizer.hashForLog(trimmedIdentifier)}',
      );
      return Failure(e);
    } catch (e) {
      _rateLimiter.recordFailedAttempt(trimmedIdentifier);
      return Failure(
        AppException(
          AppLocalizations.current.tr('unexpectedError'),
          ErrorType.unknown,
          e,
        ),
      );
    }
  }

  static bool _isValidIdentifier(String identifier) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (emailRegex.hasMatch(identifier)) return true;

    final normalizedPhone = identifier.replaceAll(RegExp(r'[^0-9+]'), '');
    return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalizedPhone);
  }
}
