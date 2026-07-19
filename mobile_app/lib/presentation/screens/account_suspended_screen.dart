import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';

/// Shown when the logged-in user's tenant (company) has been suspended by
/// the platform owner. The user can still authenticate (their password
/// still works) but `current_tenant_id()` returns NULL server-side, so
/// every data query comes back empty — this screen explains why instead of
/// leaving them looking at a blank app.
class AccountSuspendedScreen extends StatelessWidget {
  const AccountSuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  size: 72,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  t.tr('accountSuspendedTitle'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t.tr('accountSuspendedMessage'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.read<AuthProvider>().logout(),
                  child: Text(t.tr('logout')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
