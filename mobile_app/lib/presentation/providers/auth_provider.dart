import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ensdim_landscape/application/use_cases/login_use_case.dart';
import 'package:ensdim_landscape/application/use_cases/logout_use_case.dart';
import 'package:ensdim_landscape/core/notifications/notification_service.dart';
import 'package:ensdim_landscape/core/security/secure_logger.dart';
import 'package:ensdim_landscape/core/types/result.dart';
import 'package:ensdim_landscape/domain/entities/app_user.dart';
import 'package:ensdim_landscape/domain/repositories/auth_repository.dart';
import 'package:ensdim_landscape/infrastructure/storage/secure_storage_service.dart';

/// Authentication lifecycle states.
enum AuthStatus {
  /// App just launched; session not yet checked.
  initial,

  /// An async auth operation is in progress.
  loading,

  /// User is authenticated.
  authenticated,

  /// No active session.
  unauthenticated,

  /// Last auth operation failed.
  error,
}

/// Manages authentication state across the application.
///
/// Security features:
/// - Persists user role in encrypted secure storage
/// - Auto-logout on session timeout (30 minutes inactivity)
/// - Clears all sensitive data on logout
/// - Secure logging (no tokens/passwords in logs)
class AuthProvider extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final AuthRepository _authRepository;
  final SecureStorageService _secureStorage;

  /// Session timeout duration — auto-logout after this period of inactivity.
  static const Duration sessionTimeout = Duration(minutes: 30);

  AuthStatus _status = AuthStatus.initial;
  AppUser? _user;
  String? _errorMessage;

  AuthProvider({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required AuthRepository authRepository,
    required SecureStorageService secureStorage,
  }) : _loginUseCase = loginUseCase,
       _logoutUseCase = logoutUseCase,
       _authRepository = authRepository,
       _secureStorage = secureStorage;

  // --- Public getters ---
  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;

  /// Checks for an existing session on app startup.
  /// Also validates session timeout.
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      // Check session timeout first
      final isTimedOut = await _isSessionTimedOut();
      if (isTimedOut) {
        SecureLogger.info('Auth', 'انتهت الجلسة بسبب عدم النشاط');
        await _performCleanLogout();
        return;
      }

      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        _user = user;
        _status = AuthStatus.authenticated;
        await _secureStorage.saveUserId(user.id);
        await _secureStorage.saveUserRole(user.role);
        await _secureStorage.updateLastActivity();
        // Register FCM token for existing sessions (not just fresh logins)
        unawaited(NotificationService.instance.registerToken(user.id));
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  /// Attempts login with the given credentials.
  Future<void> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _loginUseCase(email, password);

    switch (result) {
      case Success<AppUser>(:final data):
        _user = data;
        _status = AuthStatus.authenticated;
        // Persist to secure storage
        await _secureStorage.saveUserId(data.id);
        await _secureStorage.saveUserRole(data.role);
        await _secureStorage.updateLastActivity();
        // Register FCM token so this device receives push notifications
        unawaited(NotificationService.instance.registerToken(data.id));
      case Failure<AppUser>(:final error):
        _errorMessage = error.message;
        _status = AuthStatus.error;
    }

    notifyListeners();
  }

  /// Signs out, clears all secure data, and resets state.
  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    await _performCleanLogout();
  }

  Future<bool> updateProfile({required String fullName}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.updateProfile(fullName: fullName);
      _status = AuthStatus.authenticated;
      await _secureStorage.updateLastActivity();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String newPassword) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.changePassword(newPassword);
      _status = AuthStatus.authenticated;
      await _secureStorage.updateLastActivity();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeClientFirstLoginSetup({
    required String email,
    required String newPassword,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authRepository.completeClientFirstLoginSetup(
        email: email,
        newPassword: newPassword,
      );
      _status = AuthStatus.authenticated;
      await _secureStorage.updateLastActivity();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Clears an error so the UI can dismiss error banners.
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Should be called on significant user interactions to keep the session alive.
  Future<void> touch() async {
    await _secureStorage.updateLastActivity();
  }

  // --- Private helpers ---

  Future<bool> _isSessionTimedOut() async {
    final lastActivity = await _secureStorage.getLastActivity();
    if (lastActivity == null) return false;

    final elapsed = DateTime.now().difference(lastActivity);
    return elapsed > sessionTimeout;
  }

  Future<void> _performCleanLogout() async {
    // Revoke FCM token before wiping the user ID
    if (_user != null) {
      unawaited(NotificationService.instance.clearToken(_user!.id));
    }

    try {
      await _logoutUseCase();
    } catch (_) {
      // Continue cleanup even if server logout fails
    }

    // Wipe all encrypted storage
    await _secureStorage.clearAll();

    _user = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
