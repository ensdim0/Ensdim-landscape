import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/l10n/strings_en.dart';
import 'package:bustan_amari/core/l10n/strings_ar.dart';
import 'package:bustan_amari/presentation/providers/admin_provider.dart';
import 'package:bustan_amari/presentation/screens/admin/widgets/admin_date_filter_bar.dart';
import 'package:bustan_amari/presentation/screens/admin/widgets/charts/visit_status_chart.dart';

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  String _txt(AppLocalizations t, String ar, String en) {
    return t.locale.languageCode == 'ar' ? ar : en;
  }

  String _num(num n) => n.toStringAsFixed(3);

  String _pct(double value) => '${(value * 100).toStringAsFixed(0)}%';

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _fmtDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final contracts = provider.filteredContracts;
        final visits = provider.visitsInDateRange;

        final activeContracts = contracts.where((c) {
          return c['status']?.toString() == 'active';
        }).length;
        final pendingContracts = contracts.where((c) {
          return c['status']?.toString() == 'pending';
        }).length;
        final terminatedContracts = contracts.where((c) {
          return c['status']?.toString() == 'terminated';
        }).length;
        final expiredContracts = contracts.where((c) {
          return c['status']?.toString() == 'expired';
        }).length;

        final visitCounts = provider.visitStatusCountsInDateRange;
        final plannedVisits = visitCounts['planned'] ?? 0;
        final inProgressVisits = visitCounts['in_progress'] ?? 0;
        final completedVisits = visitCounts['completed'] ?? 0;
        final cancelledVisits = visitCounts['cancelled'] ?? 0;

        final totalVisits = visits.length;
        final visitCompletionRate = totalVisits == 0
            ? 0.0
            : completedVisits / totalVisits;

        final revenue = provider.periodRevenue;
        final expenses = provider.periodExpenses;
        final net = provider.periodNet;
        final netPositive = net >= 0;
        final activeRate = contracts.isEmpty
            ? 0.0
            : activeContracts / contracts.length;

        final recentPayments = provider.recentPayments.take(5).toList();
        final topExpenses = provider.topExpenses.take(5).toList();

        return RefreshIndicator(
          onRefresh: provider.loadDashboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              AdminDateFilterBar(
                range: provider.dateRange,
                onReset: provider.resetFilters,
                onChange: provider.setDateRange,
              ),
              const SizedBox(height: 12),
              _healthBanner(
                context,
                title: netPositive
                    ? _txt(t, 'الوضع المالي إيجابي', 'Financially Healthy')
                    : _txt(t, 'تنبيه مالي', 'Financial Alert'),
                subtitle: netPositive
                    ? _txt(
                        t,
                        'الإيرادات أعلى من المصروفات خلال الفترة المحددة.',
                        'Revenue is above expenses for the selected period.',
                      )
                    : _txt(
                        t,
                        'المصروفات أعلى من الإيرادات. راقب التحصيلات فورًا.',
                        'Expenses are above revenue. Review collections now.',
                      ),
                accent: netPositive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _kpi(
                    context,
                    _txt(t, 'العقود النشطة', 'Active Contracts'),
                    '$activeContracts',
                    Icons.assignment_turned_in_rounded,
                  ),
                  _kpi(
                    context,
                    _txt(t, 'عقود معلقة', 'Pending Contracts'),
                    '$pendingContracts',
                    Icons.hourglass_top_rounded,
                  ),
                  _kpi(
                    context,
                    _txt(t, 'الإيرادات', 'Revenue'),
                    '${_num(revenue)} ${t.tr('currencyKwd')}',
                    Icons.trending_up_rounded,
                  ),
                  _kpi(
                    context,
                    _txt(t, 'المصروفات', 'Expenses'),
                    '${_num(expenses)} ${t.tr('currencyKwd')}',
                    Icons.trending_down_rounded,
                  ),
                  _kpi(
                    context,
                    _txt(t, 'الصافي', 'Net'),
                    '${_num(net)} ${t.tr('currencyKwd')}',
                    Icons.account_balance_wallet_rounded,
                  ),
                  _kpi(
                    context,
                    _txt(t, 'الزيارات المكتملة', 'Completed Visits'),
                    '$completedVisits',
                    Icons.check_circle_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _title(context, _txt(t, 'ملخص شامل', 'Business Snapshot')),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _detailRow(
                        context,
                        _txt(t, 'إجمالي العقود', 'Total Contracts'),
                        '${contracts.length}',
                      ),
                      _detailRow(
                        context,
                        _txt(t, 'معدل العقود النشطة', 'Active Rate'),
                        _pct(activeRate),
                      ),
                      _detailRow(
                        context,
                        _txt(t, 'معدل إتمام الزيارات', 'Visit Completion Rate'),
                        _pct(visitCompletionRate),
                      ),
                      _detailRow(
                        context,
                        _txt(t, 'زيارات متغيرة اليوم', 'Visits Changed Today'),
                        '${provider.visitsChangedToday.length}',
                      ),
                      _detailRow(
                        context,
                        _txt(t, 'التحويلات بالفترة', 'Transfers in Period'),
                        '${provider.transferCount}',
                      ),
                      _detailRow(
                        context,
                        _txt(t, 'العقود المنتهية', 'Expired / Terminated'),
                        '${expiredContracts + terminatedContracts}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _title(
                context,
                _txt(t, 'ملخص حالات الزيارات', 'Visit Status Summary'),
              ),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: VisitStatusChart(statusCounts: visitCounts),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _status(
                        context,
                        _txt(t, 'مجدولة', 'Planned'),
                        plannedVisits,
                      ),
                      _status(
                        context,
                        _txt(t, 'جارية', 'In Progress'),
                        inProgressVisits,
                      ),
                      _status(
                        context,
                        _txt(t, 'مكتملة', 'Completed'),
                        completedVisits,
                      ),
                      _status(
                        context,
                        _txt(t, 'ملغاة', 'Cancelled'),
                        cancelledVisits,
                      ),
                      _status(
                        context,
                        _txt(t, 'عقود نشطة', 'Active Contracts'),
                        activeContracts,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _title(context, _txt(t, 'آخر التحصيلات', 'Recent Payments')),
              _listCard(
                context,
                recentPayments.map((payment) {
                  final contractId = payment['contract_id']?.toString() ?? '';
                  final contractCode = provider.contractCodeById(contractId);
                  final contract = provider.contractById(contractId);
                  final rawName = contract != null
                      ? contract['client_name']
                      : null;
                  final nameText = rawName?.toString().trim() ?? '';
                  final clientName = nameText.isNotEmpty ? nameText : '—';
                  final amount = _num((payment['amount'] as num?) ?? 0);
                  final method = payment['payment_method']?.toString() ?? '';
                  final lowerMethod = method.toLowerCase();
                  String methodKey;
                  if (lowerMethod == 'cash') {
                    methodKey = 'paymentMethodCash';
                  } else if (lowerMethod == 'transfer' ||
                      lowerMethod == 'bank_transfer') {
                    methodKey = 'paymentMethodTransfer';
                  } else if (lowerMethod == 'cheque') {
                    methodKey = 'paymentMethodCheque';
                  } else if (lowerMethod == 'card') {
                    methodKey = 'paymentMethodCard';
                  } else if (lowerMethod == 'gateway') {
                    methodKey = 'paymentMethodGateway';
                  } else {
                    methodKey = 'paymentMethodCash';
                  }
                  final enMethodLabel = stringsEn[methodKey] ?? method;
                  final arMethodLabel = stringsAr[methodKey] ?? method;
                  final methodLabelBoth = '$arMethodLabel • $enMethodLabel';

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(
                      "$clientName • ${contractCode.isNotEmpty ? contractCode : (contractId.isNotEmpty ? contractId : '—')} • $amount ${t.tr('currencyKwd')}",
                    ),
                    subtitle: Text(
                      "$methodLabelBoth • ${_fmtDate(_parseDate(payment['payment_date']))}",
                    ),
                  );
                }).toList(),
                emptyText: _txt(
                  t,
                  'لا توجد تحصيلات ضمن الفلتر',
                  'No payments in the selected range',
                ),
              ),
              const SizedBox(height: 16),
              _title(context, _txt(t, 'أكبر المصروفات', 'Top Expenses')),
              _listCard(
                context,
                topExpenses.map((expense) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.trending_down_rounded),
                    title: Text(
                      '${expense['description'] ?? '—'} • ${_num((expense['amount'] as num?) ?? 0)} ${t.tr('currencyKwd')}',
                    ),
                    subtitle: Text(
                      _fmtDate(_parseDate(expense['expense_date'])),
                    ),
                  );
                }).toList(),
                emptyText: _txt(
                  t,
                  'لا توجد مصروفات ضمن الفلتر',
                  'No expenses in the selected range',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _title(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _status(BuildContext context, String title, int count) {
    return Chip(
      label: Text('$title: $count'),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    );
  }

  Widget _healthBanner(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.insights_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listCard(
    BuildContext context,
    List<Widget> items, {
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(emptyText, textAlign: TextAlign.center),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }

  Widget _kpi(BuildContext context, String title, String value, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 560;
    final cardWidth = isWide ? 250.0 : (screenWidth - 40) / 2;

    return SizedBox(
      width: cardWidth,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
