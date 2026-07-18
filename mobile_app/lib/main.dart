// ignore_for_file: unused_element

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bustan_amari/core/config/env.dart';
import 'package:bustan_amari/core/notifications/notification_service.dart';
import 'package:bustan_amari/core/security/device_security_checker.dart';
import 'package:bustan_amari/core/security/secure_logger.dart';
import 'package:bustan_amari/infrastructure/di/service_locator.dart';
import 'package:bustan_amari/app.dart';

final ValueNotifier<bool> _backendReady = ValueNotifier(false);
final ValueNotifier<String?> _backendError = ValueNotifier(null);
final List<String> _backendSecurityRisks = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prevent GoogleFonts from fetching fonts at runtime in release builds.
  // Bundling fonts is preferred, but disabling runtime fetch avoids a
  // network stall during cold start.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Transparent status bar with light icons for the initial dark-green splash.
  // Individual screens override this via AnnotatedRegion as needed.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  runApp(
    BootstrapRoot(
      backendReady: _backendReady,
      backendError: _backendError,
      backendSecurityRisks: _backendSecurityRisks,
    ),
  );

  // Kick off backend initialization in a guarded zone so unhandled errors are logged.
  runZonedGuarded(
    () {
      _initializeBackend();
    },
    (error, stack) {
      if (kReleaseMode) {
        SecureLogger.error('Unhandled', 'خطأ غير متوقع', error);
        _backendError.value = null;
      } else {
        debugPrint('Unhandled error: $error');
        debugPrintStack(stackTrace: stack);
        _backendError.value = '$error';
      }
    },
  );
}

Future<void> _initializeBackend() async {
  if (!Env.isConfigured) {
    throw StateError(
      'Supabase environment is not configured. '
      'Use --dart-define=SUPABASE_URL and --dart-define=SUPABASE_ANON_KEY',
    );
  }

  // Firebase must be initialized before Supabase so the background message
  // handler is registered before any isolate can be spawned by FCM.
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final securityFuture = _collectSecurityRisks();

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  await ServiceLocator.instance.initialize(Supabase.instance.client);
  final securityRisks = await securityFuture;

  _backendSecurityRisks.clear();
  _backendSecurityRisks.addAll(securityRisks);
  _backendReady.value = true;
}

class BootstrapRoot extends StatelessWidget {
  final ValueNotifier<bool> backendReady;
  final ValueNotifier<String?> backendError;
  final List<String> backendSecurityRisks;

  const BootstrapRoot({
    super.key,
    required this.backendReady,
    required this.backendError,
    required this.backendSecurityRisks,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: backendError,
      builder: (context, error, _) {
        if (error != null) {
          return _BootstrapErrorApp(details: error);
        }
        return ValueListenableBuilder<bool>(
          valueListenable: backendReady,
          builder: (context, ready, _) {
            if (!ready) {
              return const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: _BootstrapSplashScreen(),
              );
            }
            return App(securityRisks: backendSecurityRisks);
          },
        );
      },
    );
  }
}

Future<List<String>> _collectSecurityRisks() async {
  // Keep startup permissive in release so legitimate devices are not blocked
  // by false positives from device-integrity heuristics.
  if (!kReleaseMode) return const [];

  final check = await DeviceSecurityChecker.performCheck();
  if (check.isRooted) {
    return const ['الجهاز مكسور الحماية (Rooted/Jailbroken)'];
  }
  return const [];
}

class _BootstrapSplashApp extends StatelessWidget {
  const _BootstrapSplashApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _BootstrapSplashScreen(),
    );
  }
}

class _BootstrapSplashScreen extends StatelessWidget {
  const _BootstrapSplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF30461F), Color(0xFF3E6530), Color(0xFF2E5C1F)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEA8E20).withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEAE7E0).withValues(alpha: 0.05),
                ),
              ),
            ),
            const SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFF9F4F0),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Image(
                            image: AssetImage('assets/app_icon.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    Text(
                      'Bustan Amari',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 28),
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0x4DFFFFFF),
                            ),
                          ),
                          CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFEA8E20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  final String? details;

  const _BootstrapErrorApp({this.details});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              details == null
                  ? 'حدث خطأ أثناء تشغيل التطبيق. حاول إعادة الفتح.'
                  : 'Startup error: $details',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
