import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/presentation/providers/admin_provider.dart';
import 'package:ensdim_landscape/presentation/screens/admin/widgets/admin_date_filter_bar.dart';
import 'package:ensdim_landscape/presentation/screens/admin/widgets/charts/revenue_expenses_chart.dart';
import 'package:ensdim_landscape/presentation/screens/admin/widgets/charts/payment_methods_chart.dart';

class AdminFinanceTab extends StatelessWidget {
  const AdminFinanceTab({super.key});

  String _txt(AppLocalizations t, String ar, String en) {
    return t.locale.languageCode == 'ar' ? ar : en;
  }

  String _fmtNum(num n) => n.toStringAsFixed(3);

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  DateTime _parse(dynamic raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final revenue = provider.periodRevenue;
        final expenses = provider.periodExpenses;
        final net = provider.periodNet;

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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _card(
                    context,
                    _txt(t, 'الإيرادات', 'Revenue'),
                    '${_fmtNum(revenue)} ${t.tr('currencyKwd')}',
                    Icons.trending_up_rounded,
                  ),
                  _card(
                    context,
                    _txt(t, 'المصاريف', 'Expenses'),
                    '${_fmtNum(expenses)} ${t.tr('currencyKwd')}',
                    Icons.trending_down_rounded,
                  ),
                  _card(
                    context,
                    _txt(t, 'الصافي', 'Net'),
                    '${_fmtNum(net)} ${t.tr('currencyKwd')}',
                    Icons.account_balance_wallet_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _title(
                context,
                _txt(t, 'الإيرادات والمصاريف', 'Revenue vs Expenses'),
              ),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: RevenueExpensesChart(
                    revenue: revenue,
                    expenses: expenses,
                    net: net,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _title(context, _txt(t, 'طرق الدفع', 'Payment Methods')),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: PaymentMethodsChart(payments: provider.recentPayments),
                ),
              ),
              const SizedBox(height: 16),
              _title(context, _txt(t, 'أحدث الدفعات', 'Recent Payments')),
              Card(
                child: provider.recentPayments.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _txt(
                            t,
                            'لا توجد دفعات ضمن الفلتر',
                            'No payments in selected filter',
                          ),
                        ),
                      )
                    : Column(
                        children: provider.recentPayments.map((p) {
                          final amount = (p['amount'] as num?) ?? 0;
                          final code = provider.contractCodeById(
                            p['contract_id']?.toString() ?? '',
                          );
                          return InkWell(
                            onTap: () =>
                                _showPaymentDetails(context, t, provider, p),
                            child: ListTile(
                              leading: const Icon(Icons.payments_outlined),
                              title: Text(
                                '${_fmtNum(amount)} ${t.tr('currencyKwd')}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                '#$code • ${_fmtDate(_parse(p['payment_date']))} • ${p['payment_method'] ?? 'cash'}',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _title(context, _txt(t, 'أعلى المصاريف', 'Top Expenses')),
              Card(
                child: provider.topExpenses.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _txt(
                            t,
                            'لا توجد مصاريف ضمن الفلتر',
                            'No expenses in selected filter',
                          ),
                        ),
                      )
                    : Column(
                        children: provider.topExpenses.map((e) {
                          final amount = (e['amount'] as num?) ?? 0;
                          return InkWell(
                            onTap: () => _showExpenseDetails(context, t, e),
                            child: ListTile(
                              leading: const Icon(Icons.receipt_long_outlined),
                              title: Text(
                                e['description']?.toString() ??
                                    _txt(t, 'مصروف', 'Expense'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _fmtDate(_parse(e['expense_date'])),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_fmtNum(amount)} ${t.tr('currencyKwd')}',
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
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

  Widget _card(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 560;
    final cardWidth = isWide ? 250.0 : (screenWidth - 40) / 2;

    return SizedBox(
      width: cardWidth,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDetails(
    BuildContext context,
    AppLocalizations t,
    AdminProvider provider,
    Map<String, dynamic> payment,
  ) {
    final contract = provider.contractById(
      payment['contract_id']?.toString() ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: ListView(
                children: [
                  Text(
                    _txt(t, 'تفاصيل الدفعة', 'Payment Details'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    context,
                    _txt(t, 'المبلغ', 'Amount'),
                    '${_fmtNum((payment['amount'] as num?) ?? 0)} ${t.tr('currencyKwd')}',
                  ),
                  _detailRow(
                    context,
                    _txt(t, 'طريقة الدفع', 'Method'),
                    payment['payment_method']?.toString() ?? 'cash',
                  ),
                  _detailRow(
                    context,
                    _txt(t, 'تاريخ الدفع', 'Payment Date'),
                    _fmtDate(_parse(payment['payment_date'])),
                  ),
                  _detailRow(
                    context,
                    _txt(t, 'رقم العقد', 'Contract Code'),
                    '#${contract?['code'] ?? provider.contractCodeById(payment['contract_id']?.toString() ?? '')}',
                  ),
                  _detailRow(
                    context,
                    _txt(t, 'اسم العميل', 'Client'),
                    contract?['client_name']?.toString() ?? '—',
                  ),
                  _detailRow(
                    context,
                    _txt(t, 'ملاحظات', 'Notes'),
                    payment['notes']?.toString().trim().isNotEmpty == true
                        ? payment['notes'].toString()
                        : _txt(t, 'لا توجد ملاحظات', 'No notes'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showExpenseDetails(
    BuildContext context,
    AppLocalizations t,
    Map<String, dynamic> expense,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.62,
              child: ListView(
                children: [
                  Text(
                    _txt(t, 'تفاصيل المصروف', 'Expense Details'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    context,
                    _txt(t, 'الوصف', 'Description'),
                    expense['description']?.toString() ??
                        _txt(t, 'مصروف', 'Expense'),
                  ),
                  _detailRow(
                    context,
                    _txt(t, 'المبلغ', 'Amount'),
                    '${_fmtNum((expense['amount'] as num?) ?? 0)} ${t.tr('currencyKwd')}',
                  ),
                  _detailRow(
                    context,
                    _txt(t, 'تاريخ المصروف', 'Expense Date'),
                    _fmtDate(_parse(expense['expense_date'])),
                  ),
                  _detailRow(
                    context,
                    _txt(t, 'المركبة', 'Vehicle'),
                    expense['vehicle_id']?.toString() ?? '—',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
