import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/core/theme/app_dimensions.dart';
import 'package:ensdim_landscape/domain/entities/app_user.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';
import 'package:ensdim_landscape/presentation/widgets/app_text_field.dart';
import 'package:ensdim_landscape/presentation/widgets/global_contact_bars.dart';

class ClientFirstLoginSetupScreen extends StatefulWidget {
  final AppUser user;

  const ClientFirstLoginSetupScreen({super.key, required this.user});

  @override
  State<ClientFirstLoginSetupScreen> createState() =>
      _ClientFirstLoginSetupScreenState();
}

class _ClientFirstLoginSetupScreenState
    extends State<ClientFirstLoginSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final ok = await auth.completeClientFirstLoginSetup(
      email: _emailController.text,
      newPassword: _passwordController.text,
    );

    if (!mounted) return;

    final t = AppLocalizations.of(context);
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.tr('firstLoginSetupSuccess'))));
    }
  }

  bool _isValidEmail(String email) {
    final value = email.trim().toLowerCase();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary700,
                AppColors.primary800,
                AppColors.primary900,
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Card(
                        elevation: AppElevation.card,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.tr('firstLoginSetupTitle'),
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  t.tr('firstLoginSetupSubtitle'),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  widget.user.fullName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary700,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                AppTextField(
                                  controller: _emailController,
                                  labelText: t.tr('firstLoginSetupEmailLabel'),
                                  hintText: t.tr('firstLoginSetupEmailHint'),
                                  prefixIcon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  enabled: !auth.isLoading,
                                  validator: (value) {
                                    final text = (value ?? '').trim();
                                    if (text.isEmpty) {
                                      return t.tr('emailRequired');
                                    }
                                    if (!_isValidEmail(text)) {
                                      return t.tr('invalidEmailFormat');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppTextField(
                                  controller: _passwordController,
                                  labelText: t.tr(
                                    'firstLoginSetupNewPasswordLabel',
                                  ),
                                  prefixIcon: Icons.lock_outline_rounded,
                                  isPassword: true,
                                  textInputAction: TextInputAction.next,
                                  enabled: !auth.isLoading,
                                  validator: (value) {
                                    final text = (value ?? '').trim();
                                    if (text.length < 6) {
                                      return t.tr('passwordTooShort');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppTextField(
                                  controller: _confirmPasswordController,
                                  labelText: t.tr(
                                    'firstLoginSetupConfirmPasswordLabel',
                                  ),
                                  prefixIcon: Icons.verified_user_outlined,
                                  isPassword: true,
                                  textInputAction: TextInputAction.done,
                                  enabled: !auth.isLoading,
                                  validator: (value) {
                                    if ((value ?? '').trim() !=
                                        _passwordController.text.trim()) {
                                      return t.tr('passwordsDoNotMatch');
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                if (auth.errorMessage != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorLight,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                    child: Text(
                                      auth.errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.xl),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: auth.isLoading ? null : _submit,
                                    child: auth.isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(t.tr('firstLoginSetupAction')),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Center(
                                  child: TextButton(
                                    onPressed: auth.isLoading
                                        ? null
                                        : () => context
                                              .read<AuthProvider>()
                                              .logout(),
                                    child: Text(t.tr('logout')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: const Center(
                    child: ContactFooterBar(textColor: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
