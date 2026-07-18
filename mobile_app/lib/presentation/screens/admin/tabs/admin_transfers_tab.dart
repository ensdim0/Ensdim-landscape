import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/presentation/providers/admin_provider.dart';
import 'package:bustan_amari/presentation/screens/admin/widgets/admin_date_filter_bar.dart';

class AdminTransfersTab extends StatelessWidget {
  const AdminTransfersTab({super.key});

  String _txt(AppLocalizations t, String ar, String en) {
    return t.locale.languageCode == 'ar' ? ar : en;
  }

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

  String _fmtNum(num n) => n.toStringAsFixed(3);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final transfers = provider.filteredTransferPayments;
        final total = transfers.fold<num>(
          0,
          (s, p) => s + ((p['amount'] as num?) ?? 0),
        );

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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text(_txt(t, 'إجمالي التحويلات', 'Total Transfers')),
                  subtitle: Text(
                    '${transfers.length} ${_txt(t, 'عملية', 'records')}',
                  ),
                  trailing: Text('${_fmtNum(total)} ${t.tr('currencyKwd')}'),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: transfers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _txt(
                            t,
                            'لا توجد تحويلات ضمن الفلتر',
                            'No transfers in selected filter',
                          ),
                        ),
                      )
                    : Column(
                        children: transfers.take(100).map((p) {
                          final code = provider.contractCodeById(
                            p['contract_id']?.toString() ?? '',
                          );
                          final amount = (p['amount'] as num?) ?? 0;
                          return InkWell(
                            onTap: () =>
                                _showTransferDetails(context, t, provider, p),
                            child: ListTile(
                              leading: const Icon(
                                Icons.account_balance_outlined,
                              ),
                              title: Text(
                                '#$code • ${_fmtNum(amount)} ${t.tr('currencyKwd')}',
                              ),
                              subtitle: Text(
                                '${_fmtDate(_parse(p['payment_date']))} • ${p['payment_method'] ?? 'transfer'}',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
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

  void _showTransferDetails(
    BuildContext context,
    AppLocalizations t,
    AdminProvider provider,
    Map<String, dynamic> payment,
  ) {
    final contract = provider.contractById(
      payment['contract_id']?.toString() ?? '',
    );
    final amount = (payment['amount'] as num?) ?? 0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.64,
              child: ListView(
                children: [
                  Text(
                    _txt(t, 'تفاصيل التحويل', 'Transfer Details'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    context,
                    _txt(t, 'المبلغ', 'Amount'),
                    '${_fmtNum(amount)} ${t.tr('currencyKwd')}',
                  ),
                  _detailRow(
                    context,
                    _txt(t, 'طريقة الدفع', 'Method'),
                    payment['payment_method']?.toString() ?? 'transfer',
                  ),
                  _detailRow(
                    context,
                    _txt(t, 'تاريخ التحويل', 'Transfer Date'),
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
