import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/domain/entities/app_user.dart';
import 'package:bustan_amari/presentation/providers/auth_provider.dart';
import 'package:bustan_amari/presentation/providers/locale_provider.dart';
import 'package:bustan_amari/presentation/screens/admin/widgets/admin_theme.dart';
import 'package:bustan_amari/presentation/widgets/custom_app_bar.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppUser user;

  const AdminDashboardScreen({super.key, required this.user});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _contracts = const [];
  List<Map<String, dynamic>> _visits = const [];
  List<Map<String, dynamic>> _payments = const [];
  List<Map<String, dynamic>> _expenses = const [];

  DateTimeRange? _range;
  String _visitStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final contractsFuture = _client
          .from('contracts_view')
          .select('id, code, status, total_value, created_at, client_name')
          .order('created_at', ascending: false);

      final visitsFuture = _client
          .from('visits')
          .select(
            'id, contract_id, visit_date, status, updated_at, notes, title',
          )
          .order('updated_at', ascending: false);

      final paymentsFuture = _client
          .from('contract_payments')
          .select(
            'id, contract_id, amount, payment_method, payment_date, created_at, notes',
          )
          .order('payment_date', ascending: false);

      final expensesFuture = _client
          .from('vehicle_expenses')
          .select(
            'id, vehicle_id, description, amount, expense_date, created_at',
          )
          .order('expense_date', ascending: false);

      final results = await Future.wait([
        contractsFuture,
        visitsFuture,
        paymentsFuture,
        expensesFuture,
      ]);

      setState(() {
        _contracts = List<Map<String, dynamic>>.from(results[0] as List);
        _visits = List<Map<String, dynamic>>.from(results[1] as List);
        _payments = List<Map<String, dynamic>>.from(results[2] as List);
        _expenses = List<Map<String, dynamic>>.from(results[3] as List);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'تعذر تحميل بيانات الأدمن';
        _loading = false;
      });
    }
  }

  bool _inRange(DateTime d) {
    final range = _range;
    if (range == null) return true;
    return !d.isBefore(
          DateTime(range.start.year, range.start.month, range.start.day),
        ) &&
        !d.isAfter(
          DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
        );
  }

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _contractCode(String contractId) {
    final c = _contracts.cast<Map<String, dynamic>?>().firstWhere(
      (e) => e?['id']?.toString() == contractId,
      orElse: () => null,
    );
    return c?['code']?.toString() ?? '—';
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _fmtNum(num n) => n.toStringAsFixed(3);

  String _text(AppLocalizations t, {required String ar, required String en}) {
    return t.locale.languageCode == 'ar' ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (_loading) {
      return Theme(
        data: buildAdminTheme(Theme.of(context)),
        child: Scaffold(
          appBar: _buildAppBar(context, t),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return Theme(
        data: buildAdminTheme(Theme.of(context)),
        child: Scaffold(
          appBar: _buildAppBar(context, t),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                FilledButton(onPressed: _loadData, child: Text(t.tr('retry'))),
              ],
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final endToday = startToday.add(const Duration(days: 1));

    final visitsChangedToday = _visits.where((v) {
      final updated = _parseDate(v['updated_at']);
      return !updated.isBefore(startToday) &&
          !updated.isAfter(endToday) &&
          (v['status']?.toString() ?? 'planned') != 'planned';
    }).toList();

    final filteredVisits = _visits.where((v) {
      final updated = _parseDate(v['updated_at']);
      final status = v['status']?.toString() ?? '';
      final statusOk =
          _visitStatusFilter == 'all' || status == _visitStatusFilter;
      return _inRange(updated) && statusOk;
    }).toList();

    final transferPayments = _payments.where((p) {
      final method = (p['payment_method']?.toString() ?? '').toLowerCase();
      final d = _parseDate(p['payment_date']);
      return _inRange(d) && (method == 'transfer' || method == 'bank_transfer');
    }).toList();

    final newContracts = _contracts.where((c) {
      final d = _parseDate(c['created_at']);
      return _inRange(d);
    }).toList();

    final revenue = _payments
        .where((p) => _inRange(_parseDate(p['payment_date'])))
        .fold<num>(0, (s, p) => s + ((p['amount'] as num?) ?? 0));

    final expenses = _expenses
        .where((e) => _inRange(_parseDate(e['expense_date'])))
        .fold<num>(0, (s, e) => s + ((e['amount'] as num?) ?? 0));

    return Theme(
      data: buildAdminTheme(Theme.of(context)),
      child: Scaffold(
        appBar: _buildAppBar(context, t),
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16, 16, 16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              _buildFilters(context, t),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statCard(
                    context,
                    _text(
                      t,
                      ar: 'زيارات متغيرة اليوم',
                      en: 'Visits Changed Today',
                    ),
                    '${visitsChangedToday.length}',
                  ),
                  _statCard(
                    context,
                    _text(t, ar: 'إيرادات الفترة', en: 'Period Revenue'),
                    '${_fmtNum(revenue)} ${t.tr('currencyKwd')}',
                  ),
                  _statCard(
                    context,
                    _text(t, ar: 'مصاريف الفترة', en: 'Period Expenses'),
                    '${_fmtNum(expenses)} ${t.tr('currencyKwd')}',
                  ),
                  _statCard(
                    context,
                    _text(t, ar: 'عقود جديدة', en: 'New Contracts'),
                    '${newContracts.length}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                _text(
                  t,
                  ar: 'الزيارات (حسب تحديث الحالة)',
                  en: 'Visits (Status Updates)',
                ),
              ),
              _statusFilter(t),
              _listCard(
                filteredVisits.take(25).map((v) {
                  final code = _contractCode(
                    v['contract_id']?.toString() ?? '',
                  );
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(
                      '${v['title'] ?? v['notes'] ?? 'زيارة'} • #$code',
                    ),
                    subtitle: Text(
                      '${v['status'] ?? 'planned'} • ${_fmtDate(_parseDate(v['updated_at']))}',
                    ),
                  );
                }).toList(),
                emptyText: _text(
                  t,
                  ar: 'لا توجد زيارات ضمن الفلتر',
                  en: 'No visits in selected filter',
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                _text(t, ar: 'التحويلات على العقود', en: 'Contract Transfers'),
              ),
              _listCard(
                transferPayments.take(25).map((p) {
                  final code = _contractCode(
                    p['contract_id']?.toString() ?? '',
                  );
                  final amount = (p['amount'] as num?) ?? 0;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: Text(
                      '#$code • ${_fmtNum(amount)} ${t.tr('currencyKwd')}',
                    ),
                    subtitle: Text(
                      '${_fmtDate(_parseDate(p['payment_date']))} • ${p['payment_method'] ?? 'transfer'}',
                    ),
                  );
                }).toList(),
                emptyText: _text(
                  t,
                  ar: 'لا توجد تحويلات ضمن الفلتر',
                  en: 'No transfers in selected filter',
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                _text(t, ar: 'العقود الجديدة', en: 'New Contracts'),
              ),
              _listCard(
                newContracts.take(25).map((c) {
                  final amount = (c['total_value'] as num?) ?? 0;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      '#${c['code'] ?? '—'} • ${c['status'] ?? 'pending'}',
                    ),
                    subtitle: Text(
                      '${_fmtDate(_parseDate(c['created_at']))} • ${_fmtNum(amount)} ${t.tr('currencyKwd')}',
                    ),
                  );
                }).toList(),
                emptyText: _text(
                  t,
                  ar: 'لا توجد عقود جديدة ضمن الفلتر',
                  en: 'No new contracts in selected filter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppLocalizations t) {
    return CustomAppBar(
      title: _text(t, ar: 'لوحة الأدمن', en: 'Admin Dashboard'),
      showBackButton: false,
      leadingActions: [
        IconButton(
          icon: const Icon(Icons.language),
          tooltip: t.tr('switchLanguage'),
          onPressed: () => context.read<LocaleProvider>().toggleLocale(),
        ),
      ],
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: t.tr('logout'),
          onPressed: () async {
            await context.read<AuthProvider>().logout();
          },
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context, AppLocalizations t) {
    final range = _range;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                range == null
                    ? _text(t, ar: 'كل التواريخ', en: 'All dates')
                    : '${_fmtDate(range.start)} - ${_fmtDate(range.end)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange: _range,
                );
                if (picked != null) {
                  setState(() => _range = picked);
                }
              },
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(_text(t, ar: 'تصفية', en: 'Filter')),
            ),
            IconButton(
              tooltip: _text(t, ar: 'إعادة التعيين', en: 'Reset'),
              onPressed: () {
                final now = DateTime.now();
                setState(() {
                  _range = DateTimeRange(
                    start: DateTime(now.year, now.month, 1),
                    end: DateTime(now.year, now.month, now.day, 23, 59, 59),
                  );
                  _visitStatusFilter = 'all';
                });
              },
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusFilter(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _statusChip(t, 'all', _text(t, ar: 'الكل', en: 'All')),
            _statusChip(t, 'planned', _text(t, ar: 'مجدولة', en: 'Planned')),
            _statusChip(
              t,
              'in_progress',
              _text(t, ar: 'جارية', en: 'In Progress'),
            ),
            _statusChip(
              t,
              'completed',
              _text(t, ar: 'مكتملة', en: 'Completed'),
            ),
            _statusChip(t, 'cancelled', _text(t, ar: 'ملغاة', en: 'Cancelled')),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(AppLocalizations t, String key, String label) {
    final selected = _visitStatusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _visitStatusFilter = key),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _listCard(List<Widget> items, {required String emptyText}) {
    return Card(
      child: items.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: Text(emptyText))
          : Column(children: items),
    );
  }

  Widget _statCard(BuildContext context, String title, String value) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 550 ? 250 : double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodySmall),
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
