import 'package:bustan_amari/domain/entities/app_user.dart';

/// Contract for authentication operations.
///
/// Infrastructure layer provides the concrete implementation (e.g. Supabase).
/// Domain and application layers depend only on this abstraction.
abstract class AuthRepository {
  /// Authenticate with an email or phone identifier and password. Returns the logged-in user.
  /// Throws [AppException] on failure.
  Future<AppUser> login(String email, String password);

  /// Sign out the current user.
  Future<void> logout();

  /// Retrieve the currently authenticated user, or `null` if not logged in.
  Future<AppUser?> getCurrentUser();

  /// Update current user profile fields.
  ///
  /// Returns the refreshed [AppUser] after persistence.
  Future<AppUser> updateProfile({required String fullName});

  /// Change current authenticated user's password.
  Future<void> changePassword(String newPassword);

  /// Completes mandatory first-login setup for client users.
  ///
  /// Persists the client email and updates password, then returns refreshed user.
  Future<AppUser> completeClientFirstLoginSetup({
    required String email,
    required String newPassword,
  });
}
