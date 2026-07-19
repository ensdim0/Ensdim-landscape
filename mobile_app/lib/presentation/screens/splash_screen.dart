// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';

/// Branded splash screen shown while the app checks auth status.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final _ = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF30461F), // Deep Green
              const Color(0xFF3e6530), // Medium Green
              const Color(0xFF2e5c1f), // Darker Green
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative circles
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEA8E20).withOpacity(0.1),
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
                  color: const Color(0xFFeae7e0).withOpacity(0.05),
                ),
              ),
            ),
            // Main content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Icon/Logo
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF9F4F0).withOpacity(0.95),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.park_rounded,
                              size: 80,
                              color: const Color(0xFF30461F),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // App Name
                    Text(
                      t.tr('appName'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Subtitle
                    Text(
                      t.tr('appTagline'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 60),
                    // Loading indicator with custom styling
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.3),
                            ),
                          ),
                          CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFEA8E20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.tr('loading'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                        letterSpacing: 0.2,
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
