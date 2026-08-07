import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';

/// Shown when the logged-in user's tenant (company) is still awaiting
/// platform-owner approval after self-registration. The user can
/// authenticate, but the tenant isn't active yet so there's nothing to show
/// — this screen explains why instead of leaving them looking at a blank app.
class AccountPendingApprovalScreen extends StatelessWidget {
  const AccountPendingApprovalScreen({super.key});

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
                  Icons.access_time_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  t.tr('accountPendingTitle'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t.tr('accountPendingMessage'),
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
