import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';

/// Result of a comprehensive device security check.
class SecurityCheckResult {
  final bool isRooted;
  final bool isEmulator;
  final bool isDebugMode;
  final bool isRealDevice;

  const SecurityCheckResult({
    required this.isRooted,
    required this.isEmulator,
    required this.isDebugMode,
    required this.isRealDevice,
  });

  /// Returns `true` if any security risk is detected.
  bool get hasSecurityRisk =>
      isRooted || isEmulator || isDebugMode || !isRealDevice;

  /// Human-readable list of detected risks.
  List<String> get risks => [
    if (isRooted) 'الجهاز مكسور الحماية (Rooted/Jailbroken)',
    if (isEmulator) 'الجهاز محاكي (Emulator)',
    if (isDebugMode) 'وضع التصحيح مفعّل (Debug Mode)',
    if (!isRealDevice) 'الجهاز غير حقيقي',
  ];
}

/// Performs comprehensive device integrity verification.
///
/// Detects:
/// - Root / Jailbreak (Magisk, Substrate, Cydia, etc.)
/// - Emulator / Simulator environments
/// - Debugger attachment
/// - Non-physical devices
///
/// Uses [SafeDevice] for all hardware/platform checks.
/// In production release mode, a compromised device will block app usage.
/// In debug/profile mode, warnings are logged but the app continues.
abstract final class DeviceSecurityChecker {
  /// Runs all security checks and returns a composite result.
  static Future<SecurityCheckResult> performCheck() async {
    bool isRooted = false;
    bool isEmulator = false;
    bool isDebugMode = kDebugMode;
    bool isRealDevice = true;

    try {
      // Jailbreak / Root detection via SafeDevice
      if (Platform.isAndroid || Platform.isIOS) {
        isRooted = await SafeDevice.isJailBroken;
      }
    } catch (_) {
      // If detection itself fails, assume risk
      isRooted = true;
    }

    try {
      // Emulator detection
      if (Platform.isAndroid || Platform.isIOS) {
        isRealDevice = await SafeDevice.isRealDevice;
      }
    } catch (_) {
      isRealDevice = false;
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        isEmulator = !isRealDevice;
      }
    } catch (_) {
      isEmulator = true;
    }

    return SecurityCheckResult(
      isRooted: isRooted,
      isEmulator: isEmulator,
      isDebugMode: isDebugMode,
      isRealDevice: isRealDevice,
    );
  }

  /// Quick check: is the device rooted/jailbroken?
  static Future<bool> isDeviceCompromised() async {
    try {
      return await SafeDevice.isJailBroken;
    } catch (_) {
      return true;
    }
  }
}
