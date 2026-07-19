import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/presentation/providers/admin_provider.dart';
import 'package:ensdim_landscape/presentation/screens/admin/widgets/admin_date_filter_bar.dart';
import 'package:ensdim_landscape/presentation/screens/admin/contract_details_screen.dart';

class AdminContractsTab extends StatelessWidget {
  const AdminContractsTab({super.key});

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

  String _formatAddress(
    AppLocalizations t, {
    required String zone,
    required String block,
    required String street,
    required String avenue,
    required String house,
    required String details,
  }) {
    final isArabic = t.locale.languageCode == 'ar';
    final parts = <String>[];
    if (zone.isNotEmpty) parts.add(zone);

    final abbr = <String>[];
    if (isArabic) {
      if (block.isNotEmpty) abbr.add('ق $block');
      if (street.isNotEmpty) abbr.add('ش $street');
      if (avenue.isNotEmpty) abbr.add('ج $avenue');
      if (house.isNotEmpty) abbr.add('م $house');
      if (abbr.isNotEmpty) parts.add(abbr.join(' '));
      if (parts.isEmpty && details.isNotEmpty) return details;
      return parts.isEmpty ? _txt(t, 'غير متوفر', 'Not provided') : parts.join('، ');
    } else {
      if (block.isNotEmpty) abbr.add('B $block');
      if (street.isNotEmpty) abbr.add('St $street');
      if (avenue.isNotEmpty) abbr.add('Av $avenue');
      if (house.isNotEmpty) abbr.add('H $house');
      if (abbr.isNotEmpty) parts.add(abbr.join(' • '));
      if (parts.isEmpty && details.isNotEmpty) return details;
      return parts.isEmpty ? _txt(t, 'غير متوفر', 'Not provided') : parts.join(' • ');
    }
  }

  String _statusLabel(AppLocalizations t, String status) {
    switch (status) {
      case 'active':
        return _txt(t, 'نشط', 'Active');
      case 'expired':
        return _txt(t, 'منتهي', 'Expired');
      case 'terminated':
        return _txt(t, 'ملغي', 'Terminated');
      default:
        return _txt(t, 'معلق', 'Pending');
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case 'active':
        return cs.primaryContainer;
      case 'expired':
      case 'terminated':
        return cs.errorContainer;
      default:
        return cs.secondaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final contracts = provider.filteredContracts;

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
              TextField(
                onChanged: provider.setContractSearch,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: _txt(
                    t,
                    'بحث بالكود أو العميل أو الخط أو المنطقة',
                    'Search by code, client, line, or zone',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _locationFilter(context, t, provider),
              const SizedBox(height: 8),
              _statusFilter(context, t, provider),
              const SizedBox(height: 8),
              if (contracts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _txt(
                        t,
                        'لا توجد عقود ضمن الفلتر',
                        'No contracts in selected filter',
                      ),
                    ),
                  ),
                )
              else
                ...contracts
                    .take(100)
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _contractCard(context, t, provider, c),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _contractCard(
    BuildContext context,
    AppLocalizations t,
    AdminProvider provider,
    Map<String, dynamic> c,
  ) {
    final id = c['id']?.toString() ?? '';
    final amount = (c['total_value'] as num?) ?? 0;
    final status = c['status']?.toString() ?? 'pending';
    final visitsCount = id.isEmpty ? 0 : provider.visitsForContract(id).length;
    final payments = id.isEmpty
        ? const <Map<String, dynamic>>[]
        : provider.paymentsForContract(id);
    final paid = id.isEmpty ? 0 : provider.paidAmountForContract(id);
    final remaining = amount - paid;
    final termsCount = c['terms'] is List ? (c['terms'] as List).length : 0;
    final lineName = provider.contractLineNameById(c['line_id']?.toString());
    final zoneName = provider.contractZoneNameById(c['zone_id']?.toString());

    final address = _formatAddress(
      t,
      zone: zoneName,
      block: c['block_number']?.toString().trim() ?? '',
      street: c['street']?.toString().trim() ?? '',
      avenue: c['avenue']?.toString().trim() ?? '',
      house: c['house']?.toString().trim() ?? '',
      details: c['address_details']?.toString().trim() ?? '',
    );

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '#${c['code'] ?? '—'}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Chip(
              backgroundColor: _statusColor(context, status),
              label: Text(_statusLabel(t, status)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c['client_name']?.toString().trim().isNotEmpty == true
                          ? c['client_name'].toString()
                          : _txt(t, 'بدون اسم', 'Unnamed'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${_fmtNum(amount)} ${t.tr('currencyKwd')}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      zoneName.isNotEmpty
                          ? zoneName
                          : _txt(t, 'غير متوفر', 'Not provided'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  Text(
                    _txt(
                      t,
                      'المتبقي: ${_fmtNum(remaining)} ${t.tr('currencyKwd')}',
                      'Remaining: ${_fmtNum(remaining)} ${t.tr('currencyKwd')}',
                    ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: remaining > 0
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          _detailLine(
            context,
            _txt(t, 'تاريخ الإنشاء', 'Created At'),
            _fmtDate(_parse(c['created_at'])),
          ),
          _detailLine(
            context,
            _txt(t, 'تاريخ البداية', 'Start Date'),
            c['start_date'] != null
                ? _fmtDate(_parse(c['start_date']))
                : _txt(t, 'غير متوفر', 'Not provided'),
          ),
          _detailLine(
            context,
            _txt(t, 'تاريخ النهاية', 'End Date'),
            c['end_date'] != null
                ? _fmtDate(_parse(c['end_date']))
                : _txt(t, 'غير متوفر', 'Not provided'),
          ),
          _detailLine(
            context,
            _txt(t, 'بيانات العميل', 'Client Info'),
            '${c['client_name']?.toString().trim().isNotEmpty == true ? c['client_name'] : _txt(t, 'غير متوفر', 'Not provided')} - ${c['client_phone']?.toString().trim().isNotEmpty == true ? c['client_phone'] : _txt(t, 'غير متوفر', 'Not provided')}',
          ),
          if (c['contract_user_name']?.toString().trim().isNotEmpty == true ||
              c['contract_user_phone']?.toString().trim().isNotEmpty == true)
            _detailLine(
              context,
              _txt(t, 'العميل بالعقد', 'Contract User'),
              '${c['contract_user_name']?.toString().trim().isNotEmpty == true ? c['contract_user_name'] : _txt(t, 'غير متوفر', 'Not provided')} - ${c['contract_user_phone']?.toString().trim().isNotEmpty == true ? c['contract_user_phone'] : _txt(t, 'غير متوفر', 'Not provided')}',
            ),
          _detailLine(context, _txt(t, 'العنوان', 'Address'), address),
          _detailLine(
            context,
            _txt(t, 'الخط', 'Line'),
            lineName.isNotEmpty
                ? lineName
                : _txt(t, 'غير متوفر', 'Not provided'),
          ),
          _detailLine(
            context,
            _txt(t, 'المنطقة', 'Zone'),
            zoneName.isNotEmpty
                ? zoneName
                : _txt(t, 'غير متوفر', 'Not provided'),
          ),
          _detailLine(
            context,
            _txt(t, 'رابط الكويت فايندر', 'Kuwait Finder'),
            c['kuwait_finder_url']?.toString().trim().isNotEmpty == true
                ? c['kuwait_finder_url'].toString()
                : _txt(t, 'غير متوفر', 'Not provided'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                context,
                _txt(t, 'زيارات', 'Visits'),
                '$visitsCount',
              ),
              _summaryChip(
                context,
                _txt(t, 'دفعات', 'Payments'),
                '${payments.length}',
              ),
              _summaryChip(context, _txt(t, 'شروط', 'Terms'), '$termsCount'),
            ],
          ),
          const SizedBox(height: 8),
          _detailLine(
            context,
            _txt(t, 'المدفوع', 'Paid'),
            '${_fmtNum(paid)} ${t.tr('currencyKwd')}',
          ),
          _detailLine(
            context,
            _txt(t, 'المتبقي', 'Remaining'),
            '${_fmtNum(remaining)} ${t.tr('currencyKwd')}',
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => ContractDetailsScreen(
                    contractId: id,
                    adminProvider: provider,
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(_txt(t, 'فتح التفاصيل', 'Open Details')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _detailLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusFilter(
    BuildContext context,
    AppLocalizations t,
    AdminProvider provider,
  ) {
    Widget chip(String key, String ar, String en) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(_txt(t, ar, en)),
          selected: provider.contractStatusFilter == key,
          onSelected: (_) => provider.setContractStatusFilter(key),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('all', 'الكل', 'All'),
          chip('pending', 'معلق', 'Pending'),
          chip('active', 'نشط', 'Active'),
          chip('expired', 'منتهي', 'Expired'),
          chip('terminated', 'ملغي', 'Terminated'),
        ],
      ),
    );
  }

  Widget _locationFilter(
    BuildContext context,
    AppLocalizations t,
    AdminProvider provider,
  ) {
    final cs = Theme.of(context).colorScheme;
    final lines = provider.availableContractLines;
    final zones = provider.availableContractZones;

    final selectedLineId =
        lines.any((line) => line['id'] == provider.contractLineIdFilter)
        ? provider.contractLineIdFilter
        : null;

    final selectedZoneId =
        zones.any((zone) => zone['id'] == provider.contractZoneIdFilter)
        ? provider.contractZoneIdFilter
        : null;

    final hasAnyFilter =
        provider.contractLineIdFilter != null ||
        provider.contractZoneIdFilter != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _txt(t, 'تصفية جغرافية', 'Geographic Filter'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (hasAnyFilter)
                TextButton(
                  onPressed: () {
                    provider.setContractZoneFilter(null);
                    provider.setContractLineFilter(null);
                  },
                  child: Text(_txt(t, 'مسح', 'Clear')),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _locationDropdown(
                  context: context,
                  label: _txt(t, 'الخط', 'Line'),
                  value: selectedLineId,
                  enabled: lines.isNotEmpty,
                  allLabel: _txt(t, 'كل الخطوط', 'All lines'),
                  options: lines,
                  onChanged: provider.setContractLineFilter,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _locationDropdown(
                  context: context,
                  label: _txt(t, 'المنطقة', 'Zone'),
                  value: selectedZoneId,
                  enabled: zones.isNotEmpty,
                  allLabel: _txt(t, 'كل المناطق', 'All zones'),
                  options: zones,
                  onChanged: provider.setContractZoneFilter,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationDropdown({
    required BuildContext context,
    required String label,
    required String? value,
    required bool enabled,
    required String allLabel,
    required List<Map<String, dynamic>> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(allLabel, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        ...options.map(
          (option) => DropdownMenuItem<String?>(
            value: option['id']?.toString(),
            child: Text(
              option['name']?.toString() ?? option['id']?.toString() ?? '',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
