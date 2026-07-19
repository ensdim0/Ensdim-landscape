import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';

/// Shown when an admin account signs in on the mobile app.
///
/// Admin accounts are managed exclusively through the web dashboard —
/// this app only serves supervisors and clients. Signs the user back out
/// so they land on the login screen again once dismissed.
class AdminNotSupportedScreen extends StatelessWidget {
  const AdminNotSupportedScreen({super.key});

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
                  Icons.desktop_windows_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  t.tr('adminNotSupportedTitle'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t.tr('adminNotSupportedMessage'),
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
