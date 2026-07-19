import 'package:flutter/material.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';

/// A reusable empty-state widget.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(t.tr('retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
