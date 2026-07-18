import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/presentation/providers/admin_provider.dart';
import 'package:bustan_amari/presentation/screens/admin/widgets/admin_theme.dart';
import 'package:bustan_amari/presentation/widgets/custom_app_bar.dart';

class ContractDetailsScreen extends StatelessWidget {
  final String contractId;
  final AdminProvider adminProvider;

  const ContractDetailsScreen({
    super.key,
    required this.contractId,
    required this.adminProvider,
  });

  String _txt(AppLocalizations t, String ar, String en) {
    return t.locale.languageCode == 'ar' ? ar : en;
  }

  String _safeText(dynamic value, {String fallback = '—'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _formatDate(AppLocalizations t, dynamic value) {
    final date = _tryParseDate(value);
    if (date == null) {
      return _safeText(value, fallback: _txt(t, 'غير متوفر', 'Not provided'));
    }
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  String _formatMoney(num value) => value.toStringAsFixed(3);

  String _paymentMethodLabel(AppLocalizations t, String? method) {
    switch (method) {
      case 'cash':
        return _txt(t, 'نقدي', 'Cash');
      case 'transfer':
        return _txt(t, 'رابط', 'Transfer');
      case 'cheque':
        return _txt(t, 'شيك', 'Cheque');
      case 'card':
        return _txt(t, 'ومض', 'Card');
      case 'gateway':
        return 'UPayments';
      default:
        return method ?? _txt(t, 'غير محدد', 'Unknown');
    }
  }

  ({String label, Color color, Color bg}) _paymentStatusInfo(
    AppLocalizations t,
    Map<String, dynamic> payment,
  ) {
    final gatewayStatus = payment['gateway_status']?.toString();
    final dueDate = payment['due_date']?.toString();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (gatewayStatus == 'paid' ||
        (gatewayStatus == null && dueDate == null)) {
      return (
        label: _txt(t, 'مدفوعة', 'Paid'),
        color: AppColors.primary100,
        bg: AppColors.primary100,
      );
    }
    if (dueDate != null && dueDate.compareTo(today) < 0 && gatewayStatus != 'paid') {
      return (
        label: _txt(t, 'متأخرة', 'Late'),
        color: AppColors.errorLight,
        bg: AppColors.errorLight,
      );
    }
    if (gatewayStatus == 'pending') {
      return (
        label: _txt(t, 'في الانتظار', 'Pending'),
        color: AppColors.accent100,
        bg: AppColors.accent100,
      );
    }
    if (gatewayStatus == 'failed') {
      return (
        label: _txt(t, 'فشل الدفع', 'Failed'),
        color: AppColors.errorLight,
        bg: AppColors.errorLight,
      );
    }
    if (gatewayStatus == 'cancelled') {
      return (
        label: _txt(t, 'ملغي', 'Cancelled'),
        color: AppColors.neutral100,
        bg: AppColors.neutral100,
      );
    }
    if (dueDate != null) {
      return (
        label: _txt(t, 'مجدولة', 'Scheduled'),
        color: AppColors.accent100,
        bg: AppColors.accent100,
      );
    }
    return (
      label: _txt(t, 'مدفوعة', 'Paid'),
      color: AppColors.primary100,
      bg: AppColors.primary100,
    );
  }

  String _paymentStatusLabel(AppLocalizations t, Map<String, dynamic> payment) {
    final gatewayStatus = payment['gateway_status']?.toString();
    final dueDate = payment['due_date']?.toString();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (gatewayStatus == 'paid' ||
        (gatewayStatus == null && dueDate == null)) {
      return _txt(t, 'مدفوعة', 'Paid');
    }
    if (dueDate != null && dueDate.compareTo(today) < 0 && gatewayStatus != 'paid') {
      return '${_txt(t, 'متأخرة', 'Late')}: $dueDate';
    }
    if (gatewayStatus == 'pending') return _txt(t, 'في الانتظار', 'Pending');
    if (gatewayStatus == 'failed') return _txt(t, 'فشل الدفع', 'Failed');
    if (gatewayStatus == 'cancelled') return _txt(t, 'ملغي', 'Cancelled');
    if (dueDate != null) return '${_txt(t, 'مجدولة', 'Scheduled')}: $dueDate';
    return _txt(t, 'مدفوعة', 'Paid');
  }

  String _statusLabel(AppLocalizations t, String status) {
    switch (status) {
      case 'active':
        return _txt(t, 'نشط', 'Active');
      case 'completed':
        return _txt(t, 'مكتمل', 'Completed');
      case 'paused':
        return _txt(t, 'موقوف', 'Paused');
      case 'expired':
        return _txt(t, 'منتهي', 'Expired');
      case 'terminated':
        return _txt(t, 'ملغي', 'Terminated');
      default:
        return _txt(t, 'معلق', 'Pending');
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'active':
      case 'completed':
        return AppColors.primary100;
      case 'paused':
        return AppColors.accent100;
      case 'expired':
      case 'terminated':
        return AppColors.errorLight;
      default:
        return AppColors.neutral100;
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openContractImageViewer(
    BuildContext context,
    AppLocalizations t,
    String imageUrl,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ContractImageViewerScreen(
          imageUrl: imageUrl,
          title: _txt(t, 'صورة العقد', 'Contract Image'),
        ),
      ),
    );
  }

  String _extractCleanedNotes(Map<String, dynamic> contract) {
    final notes = contract['notes']?.toString() ?? '';
    const prefix = '[[PALM_INFO]]';
    if (!notes.startsWith(prefix)) return notes.trim();
    final rest = notes.substring(prefix.length);
    final jsonEnd = rest.indexOf('\n');
    if (jsonEnd == -1) return '';
    return rest.substring(jsonEnd + 1).trim();
  }

  Map<String, dynamic>? _extractPalmInfo(Map<String, dynamic> contract) {
    final rawPalm = contract['palm_info'];
    if (rawPalm is Map) {
      return Map<String, dynamic>.from(rawPalm);
    }

    final notes = contract['notes']?.toString() ?? '';
    const prefix = '[[PALM_INFO]]';
    if (!notes.startsWith(prefix)) return null;

    try {
      final rest = notes.substring(prefix.length);
      final jsonEnd = rest.indexOf('\n');
      final jsonStr = jsonEnd == -1 ? rest : rest.substring(0, jsonEnd);
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _palmSpeciesLabel(AppLocalizations t, Map<String, dynamic> palmInfo) {
    final species = palmInfo['species']?.toString();
    if (species == 'washingtonia') {
      return _txt(t, 'النوع: واشنطونيا', 'Type: Washingtonia');
    }
    return _txt(t, 'النوع: بلدي', 'Type: Baladi');
  }

  Map<String, dynamic> _palmStats(Map<String, dynamic> palmInfo) {
    final species = palmInfo['species']?.toString() == 'washingtonia'
        ? palmInfo['washingtonia']
        : palmInfo['baladi'];
    if (species is Map) {
      return Map<String, dynamic>.from(species);
    }
    return const <String, dynamic>{};
  }

  int _palmCount(Map<String, dynamic> stats, String key) {
    final value = stats[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _termTitle(AppLocalizations t, dynamic term, int index) {
    if (term is Map) {
      final content = term['content']?.toString().trim() ?? '';
      if (content.isNotEmpty) return content;
      final title = term['title']?.toString().trim() ?? '';
      if (title.isNotEmpty) return title;
    }
    final text = term?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
    return '${_txt(t, 'شرط', 'Term')} ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final contract = adminProvider.contractById(contractId);
    if (contract == null) {
      return Theme(
        data: buildAdminTheme(theme),
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: CustomAppBar(
            title: _txt(t, 'تفاصيل العقد', 'Contract Details'),
            backButtonBackgroundColor: Colors.transparent,
          ),
          body: Center(
            child: Text(
              _txt(t, 'العقد غير موجود', 'Contract not found'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textLabel,
              ),
            ),
          ),
        ),
      );
    }

    final visits =
        List<Map<String, dynamic>>.from(
          adminProvider.visitsForContract(contractId),
        )..sort(
          (a, b) => (_tryParseDate(b['visit_date']) ?? DateTime(1970))
              .compareTo(_tryParseDate(a['visit_date']) ?? DateTime(1970)),
        );

    final payments =
        List<Map<String, dynamic>>.from(
          adminProvider.paymentsForContract(contractId),
        )..sort(
          (a, b) => (_tryParseDate(b['payment_date']) ?? DateTime(1970))
              .compareTo(_tryParseDate(a['payment_date']) ?? DateTime(1970)),
        );

    final total = (contract['total_value'] as num?) ?? 0;
    final paid = adminProvider.paidAmountForContract(contractId);

    final status = _safeText(contract['status'], fallback: 'pending');
    final code = _safeText(contract['code']);
    final clientName = _safeText(
      contract['client_name'],
      fallback: _txt(t, 'بدون اسم', 'Unnamed'),
    );

    final terms = contract['terms'] is List
        ? List<dynamic>.from(contract['terms'] as List)
        : <dynamic>[];

    final finderUrl = _safeText(contract['kuwait_finder_url'], fallback: '');
    final contractImage = _safeText(
      contract['contract_image_url'],
      fallback: '',
    );
    final palmInfo = _extractPalmInfo(contract);
    final resolvedContractTypeName =
        _safeText(contract['contract_type_name'], fallback: '').isNotEmpty
        ? _safeText(contract['contract_type_name'], fallback: '')
        : (adminProvider.contractTypeNameById(
                contract['contract_type_id']?.toString(),
              ) ??
              '');

    final contractUserName = _safeText(contract['contract_user_name'], fallback: '');
    final contractUserPhone = _safeText(contract['contract_user_phone'], fallback: '');
    final clientPhone = _safeText(contract['client_phone'], fallback: '');
    final zoneName = _safeText(contract['zone_name'], fallback: '');
    final lineName = _safeText(contract['line_name'], fallback: '');
    final blockNumber = _safeText(contract['block_number'], fallback: '');
    final streetVal = _safeText(contract['street'], fallback: '');
    final avenueVal = _safeText(contract['avenue'], fallback: '');
    final houseVal = _safeText(contract['house'], fallback: '');
    final addressDetails = _safeText(contract['address_details'], fallback: '');
    final cleanedNotes = _extractCleanedNotes(contract);

    return Theme(
      data: buildAdminTheme(theme),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: '${_txt(t, 'العقد', 'Contract')} #$code',
          backButtonBackgroundColor: Colors.transparent,
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16, 16, 16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // ─── Header ───────────────────────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.neutral200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            clientName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Chip(
                          backgroundColor: _statusColor(context, status),
                          label: Text(
                            _statusLabel(t, status),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_txt(t, 'رقم العقد', 'Contract Code')}: $code',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLabel,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_txt(t, 'تاريخ الإنشاء', 'Created')}: ${_formatDate(t, contract['created_at'])}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ─── KPI Cards (4) ────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricCard(
                  context,
                  _txt(t, 'القيمة الإجمالية', 'Total Value'),
                  '${_formatMoney(total)} ${t.tr('currencyKwd')}',
                ),
                _metricCard(
                  context,
                  _txt(t, 'نهاية العقد', 'End Date'),
                  _formatDate(t, contract['end_date']),
                ),
                _metricCard(
                  context,
                  _txt(t, 'نوع العقد', 'Contract Type'),
                  resolvedContractTypeName.isNotEmpty
                      ? resolvedContractTypeName
                      : _txt(t, 'غير متوفر', 'Not provided'),
                ),
                _metricCard(
                  context,
                  _txt(t, 'الخط الجغرافي', 'Line'),
                  lineName.isNotEmpty
                      ? lineName
                      : _txt(t, 'غير متوفر', 'Not provided'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ─── Client & Beneficiary ──────────────────────────────────────
            _sectionCard(
              context,
              title: _txt(t, 'بيانات العميل والمستفيد', 'Client & Beneficiary'),
              children: [
                _infoRow(
                  context,
                  _txt(t, 'العميل الرئيسي', 'Primary Client'),
                  clientName,
                ),
                if (clientPhone.isNotEmpty)
                  _infoRow(
                    context,
                    _txt(t, 'رقم الهاتف', 'Phone'),
                    clientPhone,
                  ),
                if (contractUserName.isNotEmpty || contractUserPhone.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Divider(height: 1),
                  ),
                  if (contractUserName.isNotEmpty)
                    _infoRow(
                      context,
                      _txt(t, 'اسم الحارس', 'Guard Name'),
                      contractUserName,
                    ),
                  if (contractUserPhone.isNotEmpty)
                    _infoRow(
                      context,
                      _txt(t, 'هاتف الحارس', 'Guard Phone'),
                      contractUserPhone,
                    ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // ─── Address & Location ────────────────────────────────────────
            _sectionCard(
              context,
              title: _txt(t, 'تفاصيل العنوان والموقع', 'Address & Location'),
              children: [
                if (zoneName.isNotEmpty)
                  _infoRow(context, _txt(t, 'المنطقة', 'Zone'), zoneName),
                if (blockNumber.isNotEmpty)
                  _infoRow(context, _txt(t, 'القطعة', 'Block'), blockNumber),
                if (streetVal.isNotEmpty)
                  _infoRow(context, _txt(t, 'الشارع', 'Street'), streetVal),
                if (avenueVal.isNotEmpty)
                  _infoRow(context, _txt(t, 'الجادة', 'Avenue'), avenueVal),
                if (houseVal.isNotEmpty)
                  _infoRow(context, _txt(t, 'المنزل', 'House'), houseVal),
                if (addressDetails.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _txt(t, 'ملاحظات العنوان', 'Address Notes'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF92400E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          addressDetails,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (palmInfo != null && palmInfo['isPalm'] == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _txt(t, 'تفاصيل النخيل', 'Palm Details'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF15803D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _infoRow(
                          context,
                          _txt(t, 'نوع النخيل', 'Palm Type'),
                          _palmSpeciesLabel(t, palmInfo),
                        ),
                        _infoRow(
                          context,
                          _txt(t, 'كبير ومثمر', 'Large productive'),
                          '${_palmCount(_palmStats(palmInfo), 'largeProductive')}',
                        ),
                        _infoRow(
                          context,
                          _txt(t, 'كبير وغير مثمر', 'Large non-productive'),
                          '${_palmCount(_palmStats(palmInfo), 'largeNonProductive')}',
                        ),
                        _infoRow(
                          context,
                          _txt(t, 'صغير ومثمر', 'Small productive'),
                          '${_palmCount(_palmStats(palmInfo), 'smallProductive')}',
                        ),
                        _infoRow(
                          context,
                          _txt(t, 'صغير وغير مثمر', 'Small non-productive'),
                          '${_palmCount(_palmStats(palmInfo), 'smallNonProductive')}',
                        ),
                      ],
                    ),
                  ),
                ],
                if (cleanedNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _txt(t, 'ملاحظات العقد', 'Contract Notes'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFC2410C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cleanedNotes,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (finderUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: OutlinedButton.icon(
                      onPressed: () => _openUrl(finderUrl),
                      icon: const Icon(Icons.location_on_outlined),
                      label: Text(
                        _txt(t, 'عرض الموقع في Kuwait Finder', 'View on Kuwait Finder'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // ─── Contract Image ────────────────────────────────────────────
            if (contractImage.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionCard(
                context,
                title: _txt(t, 'صورة العقد', 'Contract Image'),
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        _openContractImageViewer(context, t, contractImage),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              contractImage,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  alignment: Alignment.center,
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: const CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                alignment: Alignment.center,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            PositionedDirectional(
                              end: 10,
                              bottom: 10,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.58),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.zoom_in_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _txt(t, 'فتح الصورة', 'Open image'),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _openContractImageViewer(context, t, contractImage),
                      icon: const Icon(Icons.open_in_full_rounded),
                      label: Text(_txt(t, 'فتح الصورة', 'Open image')),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // ─── Terms ────────────────────────────────────────────────────
            _sectionCard(
              context,
              title: _txt(t, 'البنود', 'Terms'),
              children: [
                if (terms.isEmpty)
                  Text(
                    _txt(t, 'لا توجد بنود', 'No terms'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLabel,
                    ),
                  )
                else
                  ...terms.asMap().entries.map(
                    (entry) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.neutral200),
                      ),
                      child: Text(
                        _termTitle(t, entry.value, entry.key),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // ─── Visits ───────────────────────────────────────────────────
            _sectionCard(
              context,
              title: _txt(t, 'الزيارات', 'Visits'),
              children: [
                if (visits.isEmpty)
                  Text(
                    _txt(t, 'لا توجد زيارات', 'No visits'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLabel,
                    ),
                  )
                else
                  ...visits.map(
                    (visit) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.neutral200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _safeText(
                                    visit['title'],
                                    fallback: _txt(t, 'زيارة', 'Visit'),
                                  ),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: _statusColor(
                                  context,
                                  _safeText(
                                    visit['status'],
                                    fallback: 'planned',
                                  ),
                                ),
                                label: Text(
                                  _statusLabel(
                                    t,
                                    _safeText(
                                      visit['status'],
                                      fallback: 'planned',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _infoRow(
                            context,
                            _txt(t, 'تاريخ الزيارة', 'Visit Date'),
                            _formatDate(t, visit['visit_date']),
                          ),
                          _infoRow(
                            context,
                            _txt(t, 'آخر تحديث', 'Last Update'),
                            _formatDate(t, visit['updated_at']),
                          ),
                          _infoRow(
                            context,
                            _txt(t, 'الملاحظات', 'Notes'),
                            _safeText(
                              visit['notes'],
                              fallback: _txt(t, 'لا يوجد', 'No notes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // ─── Payments ─────────────────────────────────────────────────
            _sectionCard(
              context,
              title: _txt(t, 'الدفعات', 'Payments'),
              children: [
                if (payments.isEmpty)
                  Text(
                    _txt(t, 'لا توجد دفعات', 'No payments'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLabel,
                    ),
                  )
                else
                  ...payments.map((payment) {
                    final amount = (payment['amount'] as num?) ?? 0;
                    final statusInfo = _paymentStatusInfo(t, payment);
                    final notes = _safeText(payment['notes'], fallback: '');
                    final dateVal = payment['payment_date'] ?? payment['due_date'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.neutral100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.neutral200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_formatMoney(amount)} ${t.tr('currencyKwd')}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: statusInfo.bg,
                                label: Text(
                                  _paymentStatusLabel(t, payment),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _infoRow(
                            context,
                            _txt(t, 'طريقة الدفع', 'Method'),
                            _paymentMethodLabel(
                              t,
                              payment['payment_method']?.toString(),
                            ),
                          ),
                          _infoRow(
                            context,
                            _txt(t, 'التاريخ', 'Date'),
                            _formatDate(t, dateVal),
                          ),
                          if (notes.isNotEmpty)
                            _infoRow(
                              context,
                              _txt(t, 'ملاحظات', 'Notes'),
                              notes,
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(BuildContext context, String title, String value) {
    final width = (MediaQuery.of(context).size.width - 48) / 2;
    return SizedBox(
      width: width < 220 ? width : 220,
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.primary100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.primary200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
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
              ).textTheme.bodySmall?.copyWith(color: AppColors.textLabel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _ContractImageViewerScreen({
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (_, __, ___) => Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
