import 'package:flutter/material.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task.dart';
import 'package:ensdim_landscape/presentation/providers/supervisor_provider.dart';

/// Bottom sheet shown once a standalone task's visit has ended and payment
/// is still unpaid. Confirming here sets payment_status='paid' and closes
/// the task — this is the last step of its lifecycle.
///
/// Takes [provider] explicitly rather than looking it up via Provider.of —
/// this sheet's builder context isn't reliably a descendant of wherever
/// SupervisorProvider is created in this app's shell.
Future<bool> showStandaloneTaskPaymentSheet(
  BuildContext context,
  StandaloneTask task,
  SupervisorProvider provider,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _StandaloneTaskPaymentSheet(task: task, provider: provider),
  );
  return result ?? false;
}

class _StandaloneTaskPaymentSheet extends StatefulWidget {
  final StandaloneTask task;
  final SupervisorProvider provider;

  const _StandaloneTaskPaymentSheet({required this.task, required this.provider});

  @override
  State<_StandaloneTaskPaymentSheet> createState() =>
      _StandaloneTaskPaymentSheetState();
}

class _StandaloneTaskPaymentSheetState
    extends State<_StandaloneTaskPaymentSheet> {
  String? _method;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.payments_rounded, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.tr('confirmPaymentTitle'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t.tr('confirmPaymentSubtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (widget.task.cost != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.tr('taskCost'),
                    style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  Text(
                    widget.task.cost!.toStringAsFixed(2),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            t.tr('paymentMethod'),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PaymentMethodTile(
                  icon: Icons.money_rounded,
                  label: t.tr('paymentMethodCash'),
                  selected: _method == 'cash',
                  onTap: () => setState(() => _method = 'cash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentMethodTile(
                  icon: Icons.link_rounded,
                  label: t.tr('paymentMethodTransfer'),
                  selected: _method == 'transfer',
                  onTap: () => setState(() => _method = 'transfer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PaymentMethodTile(
                  icon: Icons.receipt_long_rounded,
                  label: t.tr('paymentMethodCheque'),
                  selected: _method == 'cheque',
                  onTap: () => setState(() => _method = 'cheque'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentMethodTile(
                  icon: Icons.credit_card_rounded,
                  label: t.tr('paymentMethodCard'),
                  selected: _method == 'card',
                  onTap: () => setState(() => _method = 'card'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _method == null || _submitting ? null : _confirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                t.tr('confirmPayment'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    if (_method == null) return;
    setState(() => _submitting = true);

    final t = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    final provider = widget.provider;

    final result = await provider.confirmStandaloneTaskPayment(
      taskId: widget.task.id,
      paymentMethod: _method!,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result != null && result.success) {
      navigator.pop(true);
      return;
    }

    scaffold.showSnackBar(
      SnackBar(
        content: Text(t.tr('confirmPaymentFailed')),
        backgroundColor: Colors.red,
      ),
    );
    navigator.pop(false);
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.neutral200),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.textPlaceholder),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
