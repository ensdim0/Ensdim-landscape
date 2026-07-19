// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/core/theme/app_dimensions.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';
import 'package:ensdim_landscape/presentation/providers/locale_provider.dart';
import 'package:ensdim_landscape/presentation/widgets/app_text_field.dart';
import 'package:ensdim_landscape/presentation/widgets/global_contact_bars.dart';

/// Login screen with email/password authentication.
///
/// Features:
/// - Client-side input validation
/// - Loading indicator during auth
/// - Arabic error messages
/// - Password visibility toggle
/// - Keyboard-aware submit on Enter
/// - Modern gradient background with branded colors (synced with dashboard)
/// - Responsive layout with proper spacing and typography
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    context.read<AuthProvider>().clearError();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<AuthProvider>().login(
      _emailController.text,
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Gradient matching dashboard login background
        // Linear gradient: primary700 → primary800 → primary900
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary700, // #30461F
              AppColors.primary800, // #3E6530
              AppColors.primary900, // #2E5C1F
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles (accent orange subtle)
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent500.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -70,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary50.withOpacity(0.03),
                ),
              ),
            ),
            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.xxl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo container with shadow
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary50.withOpacity(0.98),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
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
                                size: 60,
                                color: AppColors.primary700,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // App name
                      Text(
                        t.tr('appName'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Login subtitle
                      Text(
                        t.tr('login'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Form card with shadow matching dashboard
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Email field
                              AppTextField(
                                controller: _emailController,
                                labelText: t.tr('email'),
                                hintText: t.tr('emailHint'),
                                prefixIcon: Icons.person_outline,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                enabled: !isLoading,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return t.tr('emailRequired');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              // Password field
                              AppTextField(
                                controller: _passwordController,
                                labelText: t.tr('password'),
                                prefixIcon: Icons.lock_outlined,
                                isPassword: true,
                                textInputAction: TextInputAction.done,
                                enabled: !isLoading,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return t.tr('passwordRequired');
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _handleLogin(),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              // Error message
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  if (auth.errorMessage == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.md,
                                      top: AppSpacing.sm,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.errorLight,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.xs,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: AppColors.error,
                                            size: 18,
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Text(
                                              auth.errorMessage!,
                                              style: TextStyle(
                                                color: AppColors.error,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              // Login button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: Consumer<AuthProvider>(
                                  builder: (context, auth, _) {
                                    return FilledButton(
                                      onPressed: auth.isLoading
                                          ? null
                                          : _handleLogin,
                                      child: auth.isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : Text(
                                              t.tr('loginButton'),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        Navigator.pushNamed(
                                          context,
                                          '/lead_request',
                                        );
                                      },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  t.tr('newClientQuestion'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        Navigator.pushNamed(
                                          context,
                                          '/privacy-policy',
                                        );
                                      },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  t.tr('privacyPolicy'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // Contact info at bottom
                      const ContactFooterBar(textColor: Colors.white70),
                      // Footer text
                      Text(
                        'Ensdim Landscape System © 2026',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Language toggle moved to the end so it's ON TOP of everything else
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            context.read<LocaleProvider>().toggleLocale(),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.language,
                                size: 20,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                t.tr('switchLanguage'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
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
