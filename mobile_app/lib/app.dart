import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/constants/roles.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/core/theme/app_dimensions.dart';
import 'package:ensdim_landscape/domain/entities/app_user.dart';
import 'package:ensdim_landscape/infrastructure/di/service_locator.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';
import 'package:ensdim_landscape/presentation/providers/client_provider.dart';
import 'package:ensdim_landscape/presentation/providers/locale_provider.dart';
import 'package:ensdim_landscape/presentation/providers/supervisor_provider.dart';
import 'package:ensdim_landscape/presentation/screens/account_suspended_screen.dart';
import 'package:ensdim_landscape/presentation/screens/admin_not_supported_screen.dart';
import 'package:ensdim_landscape/presentation/screens/client/client_first_login_setup_screen.dart';
import 'package:ensdim_landscape/presentation/screens/client_home_screen.dart';
import 'package:ensdim_landscape/presentation/screens/login_screen.dart';
import 'package:ensdim_landscape/presentation/screens/privacy_policy_screen.dart';
import 'package:ensdim_landscape/presentation/screens/security_blocked_screen.dart';
import 'package:ensdim_landscape/presentation/screens/splash_screen.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/supervisor_dashboard_screen.dart';
import 'package:ensdim_landscape/presentation/screens/lead_request_screen.dart';

/// Global navigator key — used by NotificationService to navigate without BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Root application widget.
///
/// Sets up:
/// - [AuthProvider] and [LocaleProvider] via [MultiProvider]
/// - Material 3 theme with green (garden/Bustan) color scheme matching dashboard
/// - Arabic & English locale support with reactive switching
/// - Reactive routing based on authentication state
/// - Security gate that blocks compromised devices
class App extends StatelessWidget {
  /// If non-empty, the device failed security checks and the app
  /// should display the blocked screen.
  final List<String> securityRisks;

  const App({super.key, this.securityRisks = const []});

  @override
  Widget build(BuildContext context) {
    final sl = ServiceLocator.instance;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(sl.secureStorage)..loadSavedLocale(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            loginUseCase: sl.loginUseCase,
            logoutUseCase: sl.logoutUseCase,
            authRepository: sl.authRepository,
            secureStorage: sl.secureStorage,
          )..checkAuthStatus(),
        ),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (context) =>
                AppLocalizations.of(context).tr('appName'),

            // --- Locale (reactive via LocaleProvider) ---
            locale: localeProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localeResolutionCallback: (deviceLocale, supportedLocales) {
              final code = deviceLocale?.languageCode;
              if (code == 'ar') return const Locale('ar');
              if (code == 'en') return const Locale('en');
              return const Locale('en');
            },
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // --- Theme (synchronized with dashboard design system) ---
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.background,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary700,
                primary: AppColors.primary700,
                onPrimary: Colors.white,
                secondary: AppColors.accent500,
                onSecondary: Colors.white,
                surface: AppColors.background,
                onSurface: AppColors.textPrimary,
                error: AppColors.error,
                onError: Colors.white,
                brightness: Brightness.light,
              ).copyWith(surfaceContainer: AppColors.cardBackground),
              textTheme:
                  GoogleFonts.ibmPlexSansArabicTextTheme(
                    Theme.of(context).textTheme,
                  ).apply(
                    bodyColor: AppColors.textPrimary,
                    displayColor: AppColors.textPrimary,
                  ),
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textPrimary,
                elevation: AppElevation.appBar,
                centerTitle: true,
                titleTextStyle: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              cardTheme: CardThemeData(
                color: AppColors.cardBackground,
                elevation: AppElevation.card,
                margin: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                ),
                shadowColor: Colors.transparent,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                  borderSide: BorderSide(color: AppColors.neutral200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                  borderSide: BorderSide(color: AppColors.neutral200, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                  borderSide: BorderSide(color: AppColors.primary700, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                  borderSide: BorderSide(color: AppColors.error, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                  borderSide: BorderSide(color: AppColors.error, width: 2),
                ),
                labelStyle: TextStyle(color: AppColors.textLabel),
                hintStyle: TextStyle(color: AppColors.textPlaceholder),
                prefixIconColor: AppColors.textLabel,
                suffixIconColor: AppColors.textLabel,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  elevation: AppElevation.button,
                  textStyle: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary700,
                  textStyle: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary700,
                  side: BorderSide(color: AppColors.primary700, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
              progressIndicatorTheme: ProgressIndicatorThemeData(
                color: AppColors.primary700,
                linearMinHeight: 4,
              ),
            ),

            // --- Security-gated auth-based routing ---
            routes: {
              '/lead_request': (context) => const LeadRequestScreen(),
              '/privacy-policy': (context) => const PrivacyPolicyScreen(),
            },
            home: securityRisks.isNotEmpty
                ? SecurityBlockedScreen(risks: securityRisks)
                : Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return switch (auth.status) {
                        AuthStatus.initial ||
                        AuthStatus.loading => const SplashScreen(),
                        AuthStatus.authenticated => _buildHomeScreen(
                          auth.user!,
                        ),
                        AuthStatus.unauthenticated ||
                        AuthStatus.error => const LoginScreen(),
                      };
                    },
                  ),
          );
        },
      ),
    );
  }

  /// Returns the appropriate home screen based on the user's role.
  Widget _buildHomeScreen(AppUser user) {
    if (user.isTenantSuspended) {
      return const AccountSuspendedScreen();
    }

    return switch (user.role) {
      AppRoles.admin => const AdminNotSupportedScreen(),
      AppRoles.supervisor => ChangeNotifierProvider(
        create: (_) =>
            SupervisorProvider(ServiceLocator.instance.supervisorRepository),
        child: SupervisorDashboardScreen(user: user),
      ),
      AppRoles.client when _requiresClientFirstLoginSetup(user) =>
        ClientFirstLoginSetupScreen(user: user),
      _ => ChangeNotifierProvider(
        create: (_) => ClientProvider(ServiceLocator.instance.clientRepository),
        child: ClientHomeScreen(user: user),
      ),
    };
  }

  bool _requiresClientFirstLoginSetup(AppUser user) {
    final email = user.email.trim().toLowerCase();
    return email.isEmpty || email.endsWith('@ensdim.local');
  }
}
