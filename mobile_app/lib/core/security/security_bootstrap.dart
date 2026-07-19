import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ensdim_landscape/core/security/app_integrity_checker.dart';
import 'package:ensdim_landscape/core/security/device_security_checker.dart';
import 'package:ensdim_landscape/core/security/secure_logger.dart';

/// Orchestrates all security checks at app startup.
///
/// Call [runAllChecks] once during initialization. In release mode,
/// critical failures (root/jailbreak, tampered app) will terminate
/// the application. In debug mode, warnings are logged but execution
/// continues to allow development.
class SecurityBootstrap {
  const SecurityBootstrap._();

  /// Runs the complete security check suite.
  ///
  /// Returns `true` if the app is safe to continue.
  /// In release mode, exits the app on critical failures.
  static Future<bool> runAllChecks() async {
    SecureLogger.info('Security', 'بدء فحص الأمان...');

    // 1. Device integrity (root/jailbreak, emulator)
    final deviceResult = await _checkDevice();
    if (!deviceResult) return false;

    // 2. App integrity (tamper detection)
    final appResult = await _checkAppIntegrity();
    if (!appResult) return false;

    // 3. Platform-specific hardening
    await _applyPlatformHardening();

    SecureLogger.info('Security', 'اجتياز جميع فحوصات الأمان بنجاح');
    return true;
  }

  static Future<bool> _checkDevice() async {
    final result = await DeviceSecurityChecker.performCheck();

    if (result.hasSecurityRisk) {
      for (final risk in result.risks) {
        SecureLogger.warning('Security', risk);
      }

      // In release mode, block rooted/jailbroken devices
      if (kReleaseMode && result.isRooted) {
        SecureLogger.error(
          'Security',
          'الجهاز مكسور الحماية — تم إيقاف التطبيق',
        );
        // Give a brief delay so the log can flush
        await Future.delayed(const Duration(milliseconds: 100));
        SystemNavigator.pop(); // Gracefully close app
        return false;
      }
    }

    return true;
  }

  static Future<bool> _checkAppIntegrity() async {
    final isIntact = await AppIntegrityChecker.isAppIntact();

    if (!isIntact) {
      SecureLogger.error(
        'Security',
        'فشل التحقق من سلامة التطبيق — احتمال تلاعب',
      );

      if (kReleaseMode) {
        await Future.delayed(const Duration(milliseconds: 100));
        SystemNavigator.pop();
        return false;
      }
    }

    return true;
  }

  /// Applies platform-specific security hardening.
  static Future<void> _applyPlatformHardening() async {
    // Prevent screenshots in release mode (Android via FLAG_SECURE)
    if (kReleaseMode && Platform.isAndroid) {
      // FLAG_SECURE is set via the Android Activity in AndroidManifest.xml
      // and the native code. Here we ensure it's noted.
      SecureLogger.info('Security', 'وضع الحماية ضد لقطات الشاشة مفعّل');
    }

    // Log build fingerprint for audit
    final fingerprint = await AppIntegrityChecker.generateBuildFingerprint();
    SecureLogger.info('Security', 'بصمة البناء: $fingerprint');
  }
}
