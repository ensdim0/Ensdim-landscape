import 'package:ensdim_landscape/core/constants/roles.dart';

/// Domain entity representing an authenticated user.
///
/// This is a pure domain object with no infrastructure dependencies.
/// Role-checking convenience getters simplify presentation layer logic.
class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final String? assignedLineId;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.assignedLineId,
  });

  bool get isAdmin => role == AppRoles.admin;
  bool get isSupervisor => role == AppRoles.supervisor;
  bool get isClient => role == AppRoles.client;

  @override
  String toString() => 'AppUser(id: $id, role: $role, name: $fullName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
