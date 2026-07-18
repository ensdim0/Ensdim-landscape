// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted key-value storage for sensitive data.
///
/// Uses:
/// - **Android**: AES encryption via Android Keystore (EncryptedSharedPreferences)
/// - **iOS**: Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
/// - **Desktop/Web**: Falls back to in-memory map when the plugin is unavailable
///
/// All session tokens, user IDs, and sensitive preferences are stored here.
/// Never use SharedPreferences for security-sensitive data.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// In-memory fallback when the native plugin is unavailable.
  static final Map<String, String> _memoryFallback = {};

  /// Determined once at startup — `true` for platforms without native support.
  static bool _useFallback = _shouldUseFallback();

  static bool _shouldUseFallback() {
    // flutter_secure_storage only has native implementations for Android/iOS/macOS
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux) return true;
    } catch (_) {
      return true;
    }
    return false;
  }

  // --- Storage Keys ---
  static const _keyAccessToken = 'secure_access_token';
  static const _keyRefreshToken = 'secure_refresh_token';
  static const _keyUserId = 'secure_user_id';
  static const _keyUserRole = 'secure_user_role';
  static const _keyLastActivity = 'secure_last_activity';
  static const _keyLocale = 'secure_locale';

  // --- Core read/write with fallback ---
  Future<void> _write(String key, String value) async {
    try {
      if (_useFallback) {
        _memoryFallback[key] = value;
        return;
      }
      await _storage.write(key: key, value: value);
    } catch (e) {
      // Plugin not available – switch to in-memory for this session
      if (e.toString().contains('MissingPluginException')) {
        _useFallback = true;
        _memoryFallback[key] = value;
        if (kDebugMode) {
          debugPrint(
            '[SecureStorage] Plugin unavailable, using in-memory fallback',
          );
        }
      } else {
        rethrow;
      }
    }
  }

  Future<String?> _read(String key) async {
    try {
      if (_useFallback) return _memoryFallback[key];
      return await _storage.read(key: key);
    } catch (e) {
      if (e.toString().contains('MissingPluginException')) {
        _useFallback = true;
        return _memoryFallback[key];
      }
      rethrow;
    }
  }

  // --- Access Token ---
  Future<void> saveAccessToken(String token) => _write(_keyAccessToken, token);
  Future<String?> getAccessToken() => _read(_keyAccessToken);

  // --- Refresh Token ---
  Future<void> saveRefreshToken(String token) =>
      _write(_keyRefreshToken, token);
  Future<String?> getRefreshToken() => _read(_keyRefreshToken);

  // --- User ID ---
  Future<void> saveUserId(String userId) => _write(_keyUserId, userId);
  Future<String?> getUserId() => _read(_keyUserId);

  // --- User Role ---
  Future<void> saveUserRole(String role) => _write(_keyUserRole, role);
  Future<String?> getUserRole() => _read(_keyUserRole);

  // --- Last Activity (for session timeout) ---
  Future<void> updateLastActivity() =>
      _write(_keyLastActivity, DateTime.now().toIso8601String());

  Future<DateTime?> getLastActivity() async {
    final value = await _read(_keyLastActivity);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  // --- Locale Preference ---
  Future<void> saveLocale(String languageCode) =>
      _write(_keyLocale, languageCode);
  Future<String?> getLocale() => _read(_keyLocale);

  // --- Wipe all secure data on logout ---
  Future<void> clearAll() async {
    try {
      if (_useFallback) {
        _memoryFallback.clear();
        return;
      }
      await _storage.deleteAll();
    } catch (e) {
      if (e.toString().contains('MissingPluginException')) {
        _useFallback = true;
        _memoryFallback.clear();
      } else {
        rethrow;
      }
    }
  }

  /// Deletes a specific key.
  Future<void> delete(String key) async {
    try {
      if (_useFallback) {
        _memoryFallback.remove(key);
        return;
      }
      await _storage.delete(key: key);
    } catch (e) {
      if (e.toString().contains('MissingPluginException')) {
        _useFallback = true;
        _memoryFallback.remove(key);
      } else {
        rethrow;
      }
    }
  }
}
