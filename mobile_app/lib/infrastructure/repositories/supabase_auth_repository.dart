import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ensdim_landscape/core/constants/roles.dart';
import 'package:ensdim_landscape/core/errors/app_exception.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/domain/entities/app_user.dart';
import 'package:ensdim_landscape/domain/repositories/auth_repository.dart';

/// Supabase-backed implementation of [AuthRepository].
///
/// Mirrors the dashboard's authentication flow:
/// 1. Authenticate via `auth.signInWithPassword`
/// 2. Fetch role from `user_roles` → `roles` join
/// 3. Fetch display name from `users` table with metadata fallback
///
/// Security notes:
/// - Uses only the anon key; all data access governed by RLS policies
/// - Passwords are never stored locally; Supabase handles hashing
/// - Session tokens are managed and refreshed by supabase_flutter
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Future<AppUser> login(String email, String password) async {
    final resolvedEmail = await _resolveLoginEmail(email);

    try {
      final response = await _client.auth.signInWithPassword(
        email: resolvedEmail,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw AppException(
          AppLocalizations.current.tr('loginFailed'),
          ErrorType.unauthorized,
        );
      }

      await _syncUsersProfileForLoginResolution(user, loginIdentifier: email);
      return _buildAppUser(user);
    } on AuthException catch (e) {
      String? fallbackEmail = _legacyPhoneLoginEmail(email);
      fallbackEmail ??= await _legacyEmailForEmailIdentifier(email);
      if (e.message.contains('Invalid login credentials') &&
          fallbackEmail != null &&
          fallbackEmail != resolvedEmail) {
        try {
          final retry = await _client.auth.signInWithPassword(
            email: fallbackEmail,
            password: password,
          );

          final retryUser = retry.user;
          if (retryUser == null) {
            throw AppException(
              AppLocalizations.current.tr('loginFailed'),
              ErrorType.unauthorized,
            );
          }

          await _syncUsersProfileForLoginResolution(
            retryUser,
            loginIdentifier: email,
          );
          return _buildAppUser(retryUser);
        } on AuthException catch (retryError) {
          throw AppException(
            _mapAuthError(retryError.message),
            ErrorType.unauthorized,
            retryError,
          );
        }
      }

      throw AppException(_mapAuthError(e.message), ErrorType.unauthorized, e);
    }
  }

  Future<String> _resolveLoginEmail(String identifier) async {
    final cleaned = identifier.trim().toLowerCase();
    if (cleaned.isEmpty) {
      throw AppException(
        AppLocalizations.current.tr('invalidCredentials'),
        ErrorType.unauthorized,
      );
    }

    try {
      final data = await _client.rpc(
        'resolve_login_email',
        params: {'login_identifier': cleaned},
      );

      if (data is String && data.trim().isNotEmpty) {
        return data.trim().toLowerCase();
      }
    } catch (_) {
      // Fall through to local fallback logic.
    }

    if (cleaned.contains('@')) {
      return cleaned;
    }

    final normalizedPhone = cleaned.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalizedPhone.isEmpty) {
      throw AppException(
        AppLocalizations.current.tr('invalidCredentials'),
        ErrorType.unauthorized,
      );
    }

    return '$normalizedPhone@ensdim.local';
  }

  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AppException(
        AppLocalizations.current.tr('logoutFailed'),
        ErrorType.server,
        e,
      );
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      return await _buildAppUser(user);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> updateProfile({required String fullName}) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw AppException(
        AppLocalizations.current.tr('loginFailed'),
        ErrorType.unauthorized,
      );
    }

    try {
      final updatePayload = <String, dynamic>{};
      updatePayload['full_name'] = fullName.trim();

      if (updatePayload.isNotEmpty) {
        await _client
            .from('users')
            .update(updatePayload)
            .eq('id', currentUser.id);
      }

      final metadata = <String, dynamic>{...?currentUser.userMetadata};
      metadata['full_name'] = fullName.trim();
      metadata['fullName'] = fullName.trim();

      await _client.auth.updateUser(UserAttributes(data: metadata));

      final refreshed = _client.auth.currentUser ?? currentUser;
      return _buildAppUser(refreshed);
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e.message), ErrorType.server, e);
    } catch (e) {
      throw AppException(
        AppLocalizations.current.tr('profileUpdateFailed'),
        ErrorType.server,
        e,
      );
    }
  }

  @override
  Future<void> changePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e.message), ErrorType.server, e);
    }
  }

  @override
  Future<AppUser> completeClientFirstLoginSetup({
    required String email,
    required String newPassword,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw AppException(
        AppLocalizations.current.tr('loginFailed'),
        ErrorType.unauthorized,
      );
    }

    final normalizedEmail = _normalizeEmail(email);
    final password = newPassword.trim();
    if (password.length < 6) {
      throw AppException(
        AppLocalizations.current.tr('passwordTooShort'),
        ErrorType.validation,
      );
    }

    try {
      final metadata = <String, dynamic>{...?currentUser.userMetadata};
      metadata['contact_email'] = normalizedEmail;
      metadata['first_login_completed'] = true;

      // Keep first-login setup stable: update password independently,
      // and store the client-entered email in users.email for login fallback.
      await _client.auth.updateUser(
        UserAttributes(password: password, data: metadata),
      );

      final phoneCandidate = _phoneFromLegacyAuthEmail(currentUser.email);
      final profileUpdate = <String, dynamic>{'email': normalizedEmail};
      if (phoneCandidate != null && phoneCandidate.isNotEmpty) {
        profileUpdate['phone'] = phoneCandidate;
      }

      await _client
          .from('users')
          .update(profileUpdate)
          .eq('id', currentUser.id);

      final refreshed = _client.auth.currentUser ?? currentUser;
      return _buildAppUser(refreshed);
    } on AppException {
      rethrow;
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e.message), ErrorType.server, e);
    } catch (e) {
      throw AppException(
        AppLocalizations.current.tr('firstLoginSetupFailed'),
        ErrorType.server,
        e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Fetches role and profile data, then builds the domain entity.
  Future<AppUser> _buildAppUser(User user) async {
    final roleName = await _fetchUserRole(user.id);
    final profile = await _fetchProfileData(user);

    return AppUser(
      id: user.id,
      email: profile.email,
      fullName: profile.fullName,
      phone: profile.phone,
      role: roleName,
    );
  }

  /// Queries `user_roles` joined with `roles` to determine the user's role.
  /// Falls back to [AppRoles.client] if no role is assigned.
  Future<String> _fetchUserRole(String userId) async {
    try {
      final data = await _client
          .from('user_roles')
          .select('roles(name)')
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null || data['roles'] == null) return AppRoles.client;

      final roles = data['roles'];
      if (roles is Map) {
        return (roles['name'] as String?) ?? AppRoles.client;
      }
      if (roles is List && roles.isNotEmpty) {
        return (roles[0]['name'] as String?) ?? AppRoles.client;
      }

      return AppRoles.client;
    } catch (_) {
      return AppRoles.client;
    }
  }

  /// Resolves the user's display name from the `users` table,
  /// falling back to auth metadata if the profile query fails.
  Future<({String fullName, String email, String? phone})> _fetchProfileData(
    User user,
  ) async {
    try {
      final data = await _client
          .from('users')
          .select('full_name, phone, email')
          .eq('id', user.id)
          .maybeSingle();

      final dbName = data?['full_name'] as String?;
      final dbPhone = data?['phone'] as String?;
      final dbEmail = (data?['email'] as String?)?.trim();
      final metadataEmail = (user.userMetadata?['contact_email'] as String?)
          ?.trim();
      if (dbName != null && dbName.isNotEmpty) {
        return (
          fullName: dbName,
          phone: dbPhone,
          email: _preferredEmail(
            dbEmail: dbEmail,
            metadataEmail: metadataEmail,
            authEmail: user.email,
          ),
        );
      }

      return (
        fullName:
            (user.userMetadata?['full_name'] as String?) ??
            (user.userMetadata?['fullName'] as String?) ??
            '',
        phone: dbPhone,
        email: _preferredEmail(
          dbEmail: dbEmail,
          metadataEmail: metadataEmail,
          authEmail: user.email,
        ),
      );
    } catch (_) {
      // Swallow and fall through to metadata
    }

    return (
      fullName:
          (user.userMetadata?['full_name'] as String?) ??
          (user.userMetadata?['fullName'] as String?) ??
          '',
      phone: null,
      email: _preferredEmail(
        dbEmail: null,
        metadataEmail: (user.userMetadata?['contact_email'] as String?)?.trim(),
        authEmail: user.email,
      ),
    );
  }

  String _normalizeEmail(String email) {
    final value = email.trim().toLowerCase();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) {
      throw AppException(
        AppLocalizations.current.tr('invalidEmailFormat'),
        ErrorType.validation,
      );
    }
    return value;
  }

  String _preferredEmail({
    required String? dbEmail,
    required String? metadataEmail,
    required String? authEmail,
  }) {
    final db = dbEmail?.trim() ?? '';
    final metadata = metadataEmail?.trim() ?? '';

    // When auth login email is a legacy placeholder (phone@ensdim.local),
    // prefer the contact email entered during first-login setup for display/routing.
    if (metadata.isNotEmpty && (db.isEmpty || db.endsWith('@ensdim.local'))) {
      return metadata;
    }

    if (db.isNotEmpty) return db;
    if (metadata.isNotEmpty) return metadata;

    return authEmail?.trim() ?? '';
  }

  String? _legacyPhoneLoginEmail(String identifier) {
    final cleaned = identifier.trim().toLowerCase();
    if (cleaned.contains('@')) return null;

    final normalizedPhone = cleaned.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalizedPhone.isEmpty) return null;

    return '$normalizedPhone@ensdim.local';
  }

  Future<String?> _legacyEmailForEmailIdentifier(String identifier) async {
    final cleaned = identifier.trim().toLowerCase();
    if (!cleaned.contains('@')) return null;

    try {
      final record = await _client
          .from('users')
          .select('phone')
          .eq('email', cleaned)
          .maybeSingle();

      final phone = (record?['phone'] as String?)?.trim() ?? '';
      final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (normalizedPhone.isEmpty) return null;
      return '$normalizedPhone@ensdim.local';
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncUsersProfileForLoginResolution(
    User user, {
    required String loginIdentifier,
  }) async {
    final contactEmail = (user.userMetadata?['contact_email'] as String?)
        ?.trim()
        .toLowerCase();
    final normalizedIdentifierPhone = _normalizedPhone(loginIdentifier);
    final phoneFromAuthEmail = _phoneFromLegacyAuthEmail(user.email);

    final updates = <String, dynamic>{};
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (contactEmail != null &&
        contactEmail.isNotEmpty &&
        emailRegex.hasMatch(contactEmail)) {
      updates['email'] = contactEmail;
    }

    if (normalizedIdentifierPhone != null &&
        normalizedIdentifierPhone.isNotEmpty) {
      updates['phone'] = normalizedIdentifierPhone;
    } else if (phoneFromAuthEmail != null && phoneFromAuthEmail.isNotEmpty) {
      updates['phone'] = phoneFromAuthEmail;
    }

    if (updates.isEmpty) return;

    try {
      await _client.from('users').update(updates).eq('id', user.id);
    } catch (_) {
      // Ignore sync failure to avoid blocking successful login.
    }
  }

  String? _normalizedPhone(String identifier) {
    final cleaned = identifier.trim().toLowerCase();
    if (cleaned.contains('@')) return null;

    final normalizedPhone = cleaned.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalizedPhone.isEmpty) return null;
    return normalizedPhone;
  }

  String? _phoneFromLegacyAuthEmail(String? authEmail) {
    final value = authEmail?.trim().toLowerCase() ?? '';
    if (!value.endsWith('@ensdim.local')) return null;

    final localPart = value.split('@').first;
    final normalizedPhone = localPart.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalizedPhone.isEmpty) return null;
    return normalizedPhone;
  }

  /// Maps Supabase auth error messages to localized user-friendly strings.
  String _mapAuthError(String message) {
    final t = AppLocalizations.current;
    if (message.contains('Invalid login credentials')) {
      return t.tr('invalidCredentials');
    }
    if (message.contains('Email not confirmed')) {
      return t.tr('emailNotConfirmed');
    }
    if (message.contains('Too many requests')) {
      return t.tr('tooManyRequests');
    }
    return t.tr('loginFailedRetry');
  }
}
