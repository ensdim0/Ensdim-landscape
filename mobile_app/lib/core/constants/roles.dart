/// Centralized role name constants matching the database `roles` table.
///
/// Must stay in sync with the server-side role definitions.
abstract final class AppRoles {
  static const String admin = 'admin';
  static const String supervisor = 'supervisor';
  static const String client = 'client';
}
