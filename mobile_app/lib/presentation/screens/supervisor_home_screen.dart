import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/domain/entities/app_user.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';
import 'package:ensdim_landscape/presentation/providers/locale_provider.dart';

/// Home screen shown to users with the **supervisor** role.
///
/// Displays a personalized supervisor greeting and a logout action.
class SupervisorHomeScreen extends StatelessWidget {
  final AppUser user;

  const SupervisorHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.tr('supervisorPanel')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: t.tr('switchLanguage'),
            onPressed: () => context.read<LocaleProvider>().toggleLocale(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: t.tr('logout'),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.supervisor_account_rounded,
                  size: 48,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                t.tr('welcomeSupervisor'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.fullName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.tr('logout')),
        content: Text(t.tr('logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.tr('exit')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }
}
