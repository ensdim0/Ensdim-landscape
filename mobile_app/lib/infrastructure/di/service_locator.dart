import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ensdim_landscape/application/use_cases/login_use_case.dart';
import 'package:ensdim_landscape/application/use_cases/logout_use_case.dart';
import 'package:ensdim_landscape/core/notifications/notification_service.dart';
import 'package:ensdim_landscape/core/security/login_rate_limiter.dart';
import 'package:ensdim_landscape/domain/repositories/auth_repository.dart';
import 'package:ensdim_landscape/domain/repositories/client_repository.dart';
import 'package:ensdim_landscape/domain/repositories/i_device_token_repository.dart';
import 'package:ensdim_landscape/domain/repositories/i_notification_repository.dart';
import 'package:ensdim_landscape/domain/repositories/supervisor_repository.dart';
import 'package:ensdim_landscape/infrastructure/repositories/supabase_auth_repository.dart';
import 'package:ensdim_landscape/infrastructure/repositories/supabase_client_repository.dart';
import 'package:ensdim_landscape/infrastructure/repositories/supabase_device_token_repository.dart';
import 'package:ensdim_landscape/infrastructure/repositories/supabase_notification_repository.dart';
import 'package:ensdim_landscape/infrastructure/repositories/supabase_supervisor_repository.dart';
import 'package:ensdim_landscape/infrastructure/storage/secure_storage_service.dart';

/// Simple service locator for dependency injection.
///
/// Initializes and provides singleton instances of repositories, use cases,
/// and security services.
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;

  late final AuthRepository authRepository;
  late final ClientRepository clientRepository;
  late final SupervisorRepository supervisorRepository;
  late final IDeviceTokenRepository deviceTokenRepository;
  late final INotificationRepository notificationRepository;
  late final LoginUseCase loginUseCase;
  late final LogoutUseCase logoutUseCase;
  late final SecureStorageService secureStorage;
  late final LoginRateLimiter loginRateLimiter;

  /// Must be called once after Supabase and Firebase initialization.
  Future<void> initialize(SupabaseClient supabaseClient) async {
    secureStorage = SecureStorageService();
    loginRateLimiter = LoginRateLimiter();
    authRepository = SupabaseAuthRepository(supabaseClient);
    clientRepository = SupabaseClientRepository(supabaseClient);
    supervisorRepository = SupabaseSupervisorRepository(supabaseClient);
    deviceTokenRepository = SupabaseDeviceTokenRepository(supabaseClient);
    notificationRepository = SupabaseNotificationRepository(supabaseClient);
    loginUseCase = LoginUseCase(authRepository, loginRateLimiter);
    logoutUseCase = LogoutUseCase(authRepository);

    await NotificationService.instance.initialize(deviceTokenRepository);
  }
}
