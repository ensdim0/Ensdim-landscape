import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';

/// Screen displayed when a critical security violation is detected.
///
/// Shown when the device is rooted/jailbroken or the app is tampered with.
/// Provides no way to bypass; the user must fix their device.
class SecurityBlockedScreen extends StatelessWidget {
  final List<String> risks;

  const SecurityBlockedScreen({super.key, required this.risks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.errorContainer,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 80,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  t.tr('securityAlert'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t.tr('securityRiskDetected'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 24),
                ...risks.map(
                  (risk) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            risk,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.tonal(
                  onPressed: () => SystemNavigator.pop(),
                  child: Text(t.tr('closeApp')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
