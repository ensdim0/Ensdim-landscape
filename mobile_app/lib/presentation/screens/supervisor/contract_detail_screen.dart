import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/domain/entities/contract.dart';
import 'package:bustan_amari/domain/entities/contract_payment.dart';
import 'package:bustan_amari/presentation/providers/supervisor_provider.dart';
import 'package:bustan_amari/presentation/screens/supervisor/visits_list_screen.dart';
import 'package:bustan_amari/presentation/widgets/custom_app_bar.dart';
import 'package:bustan_amari/presentation/widgets/expandable_section.dart';
import 'package:bustan_amari/presentation/widgets/status_chip.dart';
import 'package:url_launcher/url_launcher.dart';

class ContractDetailScreen extends StatelessWidget {
  final Contract contract;

  const ContractDetailScreen({super.key, required this.contract});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth < 360 ? 16.0 : 20.0;
    final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;
    final bottomActionClearance = 108.0 + bottomSafeInset;
    final zoneName = context.select<SupervisorProvider, String?>((provider) {
      final zoneId = contract.zoneId;
      if (zoneId == null || zoneId.isEmpty) return null;
      for (final zone in provider.assignedZones) {
        if (zone.id == zoneId) return zone.name;
      }
      return null;
    });
    final assignedLineName = context.select<SupervisorProvider, String?>(
      (provider) => provider.assignedLine?.name,
    );
    final lineName = contract.lineName ?? assignedLineName;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: t.tr('contractDetails'),
        backButtonBackgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          padding,
          8,
          padding,
          bottomActionClearance,
        ), // padding at bottom for button
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusHeader(theme, t),
            const SizedBox(height: 24),

            // Client info Section
            _buildSectionTitle(
              theme,
              _localizedText(t, 'بيانات العميل', 'Client Details'),
            ),
            _buildRealClientCard(theme, t),
            const SizedBox(height: 24),

            // Guard info Section
            _buildSectionTitle(
              theme,
              _localizedText(t, 'بيانات الحارس', 'Guard Details'),
            ),
            _buildGuardCard(theme, t),
            const SizedBox(height: 24),

            _buildSectionTitle(theme, t.tr('address')),
            _buildAddressCard(theme, t, zoneName, lineName),
            const SizedBox(height: 24),

            if (contract.palmInfo != null && contract.palmInfo!.isPalm) ...[
              _buildSectionTitle(
                theme,
                _localizedText(t, 'تفاصيل النخيل', 'Palm Details'),
              ),
              _buildPalmCard(theme, t, contract),
              const SizedBox(height: 24),
            ],

            _buildSectionTitle(theme, t.tr('contractDetails')),
            _buildInfoCard(theme, t, zoneName),
            const SizedBox(height: 24),

            _buildSectionTitle(
              theme,
              _localizedText(t, 'الدفعات', 'Payments'),
            ),
            _ContractPaymentsSection(contractId: contract.id),
            const SizedBox(height: 24),

            _buildSectionTitle(theme, t.tr('requestContractStatusChange')),
            const SizedBox(height: 12),
            ContractStatusRequestCard(contract: contract),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context, theme, t),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4, left: 4),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary700,
        ),
      ),
    );
  }

  Widget _buildStatusHeader(ThemeData theme, AppLocalizations t) {
    final statusLabel = switch (contract.status) {
      'active' => t.tr('statusActive'),
      'pending' => t.tr('statusPending'),
      'terminated' => t.tr('statusTerminated'),
      'expired' => t.tr('statusExpired'),
      _ => contract.status,
    };

    final statusColor = switch (contract.status) {
      'active' => Colors.green,
      'pending' => Colors.orange,
      'terminated' => Colors.red,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: AppColors.primary700,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            contract.code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (contract.clientName != null && contract.clientName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: AppColors.textLabel,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      contract.clientName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          if (contract.clientPhone != null && contract.clientPhone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.phone_rounded,
                    size: 16,
                    color: AppColors.textLabel,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      contract.clientPhone!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          StatusChip(label: statusLabel, color: statusColor),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, AppLocalizations t, String? zoneName) {
    return _ModernCard(
      child: Column(
        children: [
          _ModernInfoRow(
            icon: Icons.calendar_month_rounded,
            label: t.tr('startDate'),
            value: contract.startDate.split('T').first,
            theme: theme,
          ),
          _buildDivider(theme),
          _ModernInfoRow(
            icon: Icons.event_available_rounded,
            label: t.tr('endDate'),
            value: contract.endDate.split('T').first,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(
    ThemeData theme,
    AppLocalizations t,
    String? zoneName,
    String? lineName,
  ) {
    final shortAddressParts = <String>[];
    final isArabic = t.locale.languageCode == 'ar';
    if (contract.blockNumber != null && contract.blockNumber!.isNotEmpty) {
      shortAddressParts.add(
        '${isArabic ? 'ق' : 'B'}: ${contract.blockNumber!}',
      );
    }
    if (contract.street != null && contract.street!.isNotEmpty) {
      shortAddressParts.add('${isArabic ? 'ش' : 'S'}: ${contract.street!}');
    }
    if (contract.avenue != null && contract.avenue!.isNotEmpty) {
      shortAddressParts.add('${isArabic ? 'ج' : 'A'}: ${contract.avenue!}');
    }
    if (contract.house != null && contract.house!.isNotEmpty) {
      shortAddressParts.add('${isArabic ? 'م' : 'H'}: ${contract.house!}');
    }

    return _ModernCard(
      child: Column(
        children: [
          if (lineName != null && lineName.isNotEmpty) ...[
            _ModernInfoRow(
              icon: Icons.alt_route_rounded,
              label: _localizedText(t, 'خط', 'Line'),
              value: lineName,
              theme: theme,
            ),
            if (zoneName != null && zoneName.isNotEmpty) _buildDivider(theme),
          ],
          if (zoneName != null && zoneName.isNotEmpty) ...[
            _ModernInfoRow(
              icon: Icons.place_rounded,
              label: t.tr('zone'),
              value: zoneName,
              theme: theme,
            ),
            if (shortAddressParts.isNotEmpty ||
                (contract.addressDetails != null &&
                    contract.addressDetails!.isNotEmpty) ||
                (contract.kuwaitFinderUrl != null &&
                    contract.kuwaitFinderUrl!.isNotEmpty))
              _buildDivider(theme),
          ],
          if (shortAddressParts.isNotEmpty) ...[
            _ModernInfoRow(
              icon: Icons.location_on_rounded,
              label: t.tr('address'),
              value: shortAddressParts.join(' - '),
              singleLineValue: true,
              theme: theme,
            ),
            if ((contract.addressDetails != null &&
                    contract.addressDetails!.isNotEmpty) ||
                (contract.kuwaitFinderUrl != null &&
                    contract.kuwaitFinderUrl!.isNotEmpty))
              _buildDivider(theme),
          ],
          if (contract.addressDetails != null &&
              contract.addressDetails!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.tr('address'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contract.addressDetails!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (contract.kuwaitFinderUrl != null &&
                contract.kuwaitFinderUrl!.isNotEmpty)
              _buildDivider(theme),
          ],
          if (contract.kuwaitFinderUrl != null &&
              contract.kuwaitFinderUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(contract.kuwaitFinderUrl!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.map_rounded),
                label: Text(
                  t.locale.languageCode == 'ar'
                      ? 'فتح في كويت فايندر'
                      : 'Open in Kuwait Finder',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRealClientCard(ThemeData theme, AppLocalizations t) {
    if (contract.clientName == null && contract.clientPhone == null) {
      return _ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            _localizedText(t, 'لا توجد بيانات', 'No data available'),
            style: const TextStyle(color: AppColors.textLabel),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _ModernCard(
      child: Column(
        children: [
          if (contract.clientName != null) ...[
            _ModernInfoRow(
              icon: Icons.person_rounded,
              label: _localizedText(t, 'اسم العميل', 'Client Name'),
              value: contract.clientName!,
              theme: theme,
            ),
          ],
          if (contract.clientName != null && contract.clientPhone != null)
            _buildDivider(theme),

          if (contract.clientPhone != null) ...[
            InkWell(
              onTap: () async {
                final url = Uri.parse('tel:${contract.clientPhone}');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: _ModernInfoRow(
                icon: Icons.phone_rounded,
                label: _localizedText(t, 'رقم الموبايل', 'Mobile Number'),
                value: contract.clientPhone!,
                valueColor: AppColors.primary700, // Make it look clickable
                theme: theme,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuardCard(ThemeData theme, AppLocalizations t) {
    if (contract.contractUserName == null &&
        contract.contractUserPhone == null) {
      return _ModernCard(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            _localizedText(t, 'لا توجد بيانات', 'No data available'),
            style: const TextStyle(color: AppColors.textLabel),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _ModernCard(
      child: Column(
        children: [
          if (contract.contractUserName != null) ...[
            _ModernInfoRow(
              icon: Icons.security_rounded,
              label: _localizedText(t, 'اسم الحارس', 'Guard Name'),
              value: contract.contractUserName!,
              theme: theme,
            ),
          ],
          if (contract.contractUserName != null &&
              contract.contractUserPhone != null)
            _buildDivider(theme),
          if (contract.contractUserPhone != null) ...[
            InkWell(
              onTap: () async {
                final url = Uri.parse('tel:${contract.contractUserPhone}');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: _ModernInfoRow(
                icon: Icons.phone_rounded,
                label: _localizedText(t, 'رقم الموبايل', 'Mobile Number'),
                value: contract.contractUserPhone!,
                valueColor: AppColors.primary700,
                theme: theme,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPalmCard(
    ThemeData theme,
    AppLocalizations t,
    Contract contract,
  ) {
    final isBaladi = (contract.palmInfo?.species ?? 'baladi') == 'baladi';
    final stats = isBaladi
        ? contract.palmInfo!.baladi
        : contract.palmInfo!.washingtonia;
    final totalPalms =
        stats.largeProductive +
        stats.largeNonProductive +
        stats.smallProductive +
        stats.smallNonProductive;

    return _ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _localizedText(
                t,
                isBaladi ? 'النوع: بلدي' : 'النوع: واشنطونيا',
                isBaladi ? 'Type: Baladi' : 'Type: Washingtonia',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Prominent total palms display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.nature_rounded,
                    size: 20,
                    color: AppColors.primary700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _localizedText(t, 'إجمالي النخيل', 'Total Palms'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary700,
                    ),
                  ),
                ),
                Text(
                  '$totalPalms',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildDivider(theme),
          _ModernInfoRow(
            icon: Icons.forest_rounded,
            label: _localizedText(t, 'كبير ومثمر', 'Large Productive'),
            value: '${stats.largeProductive}',
            theme: theme,
          ),
          _buildDivider(theme),
          _ModernInfoRow(
            icon: Icons.forest_rounded,
            label: _localizedText(t, 'كبير وغير مثمر', 'Large Non-Productive'),
            value: '${stats.largeNonProductive}',
            theme: theme,
          ),
          _buildDivider(theme),
          _ModernInfoRow(
            icon: Icons.forest_rounded,
            label: _localizedText(t, 'صغير ومثمر', 'Small Productive'),
            value: '${stats.smallProductive}',
            theme: theme,
          ),
          _buildDivider(theme),
          _ModernInfoRow(
            icon: Icons.forest_rounded,
            label: _localizedText(t, 'صغير وغير مثمر', 'Small Non-Productive'),
            value: '${stats.smallNonProductive}',
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(
    BuildContext context,
    ThemeData theme,
    AppLocalizations t,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<SupervisorProvider>(),
                  child: VisitsListScreen(contract: contract),
                ),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary700,
            foregroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
          icon: const Icon(Icons.event_note_rounded, size: 24),
          label: Text(
            t.tr('visits'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Divider(height: 1, color: AppColors.neutral200),
    );
  }
}

class ContractStatusRequestCard extends StatefulWidget {
  final Contract contract;

  const ContractStatusRequestCard({super.key, required this.contract});

  @override
  State<ContractStatusRequestCard> createState() =>
      _ContractStatusRequestCardState();
}

class _ContractStatusRequestCardState extends State<ContractStatusRequestCard> {
  static const List<String> _statusOptions = [
    'active',
    'pending',
    'terminated',
    'expired',
  ];

  late String _requestedStatus;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _requestedStatus = widget.contract.status;
  }

  String _statusLabel(AppLocalizations t, String status) {
    return switch (status) {
      'active' => t.tr('statusActive'),
      'pending' => t.tr('statusPending'),
      'terminated' => t.tr('statusTerminated'),
      'expired' => t.tr('statusExpired'),
      _ => status,
    };
  }

  Future<void> _submitRequest() async {
    if (_requestedStatus == widget.contract.status || _isSubmitting) return;

    final t = AppLocalizations.of(context);
    final provider = context.read<SupervisorProvider>();

    setState(() {
      _isSubmitting = true;
    });

    try {
      await provider.requestContractStatusChange(
        contractId: widget.contract.id,
        requestedStatus: _requestedStatus,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.tr('statusChangeRequestSent')),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Contract status request failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.tr('statusChangeRequestFailed')}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final isSameAsCurrent = _requestedStatus == widget.contract.status;

    return _ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.tr('statusChangeRequestHint'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _requestedStatus,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: t.tr('requestedStatus'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.neutral200),
              ),
            ),
            items: _statusOptions
                .map(
                  (status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(_statusLabel(t, status)),
                  ),
                )
                .toList(),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _requestedStatus = value;
                    });
                  },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_isSubmitting || isSameAsCurrent)
                  ? null
                  : _submitRequest,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(t.tr('submitStatusChangeRequest')),
            ),
          ),
        ],
      ),
    );
  }
}

String _localizedText(AppLocalizations t, String arabic, String english) {
  return t.locale.languageCode == 'ar' ? arabic : english;
}

class _ContractPaymentsSection extends StatefulWidget {
  final String contractId;

  const _ContractPaymentsSection({required this.contractId});

  @override
  State<_ContractPaymentsSection> createState() =>
      _ContractPaymentsSectionState();
}

class _ContractPaymentsSectionState extends State<_ContractPaymentsSection> {
  late Future<List<ContractPayment>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<SupervisorProvider>().fetchContractPayments(
      widget.contractId,
    );
  }

  String _methodLabel(AppLocalizations t, String method) {
    return switch (method) {
      'cash' => _localizedText(t, 'نقدي', 'Cash'),
      'transfer' => _localizedText(t, 'رابط', 'Transfer'),
      'cheque' => _localizedText(t, 'شيك', 'Cheque'),
      'card' => _localizedText(t, 'ومض', 'Card'),
      'gateway' => _localizedText(t, 'دفع إلكتروني', 'Online Payment'),
      _ => method,
    };
  }

  ({String label, Color color}) _statusOf(
    AppLocalizations t,
    ContractPayment p,
  ) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final due = p.dueDate != null ? DateTime.tryParse(p.dueDate!) : null;
    final isLate =
        due != null && p.gatewayStatus != 'paid' && due.isBefore(todayOnly);

    if (p.gatewayStatus == 'paid' || (p.gatewayStatus == null && p.dueDate == null)) {
      return (label: _localizedText(t, 'مدفوعة', 'Paid'), color: Colors.green);
    }
    if (isLate) {
      return (label: _localizedText(t, 'متأخرة', 'Late'), color: Colors.red);
    }
    if (p.gatewayStatus == 'pending') {
      return (
        label: _localizedText(t, 'في انتظار الدفع', 'Awaiting payment'),
        color: Colors.orange,
      );
    }
    if (p.gatewayStatus == 'failed') {
      return (label: _localizedText(t, 'فشل الدفع', 'Failed'), color: Colors.red);
    }
    if (p.gatewayStatus == 'cancelled') {
      return (label: _localizedText(t, 'ملغي', 'Cancelled'), color: Colors.grey);
    }
    return (label: _localizedText(t, 'مجدولة', 'Scheduled'), color: Colors.blue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return FutureBuilder<List<ContractPayment>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ModernCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _ModernCard(
            child: Text(
              _localizedText(t, 'تعذر تحميل الدفعات', 'Failed to load payments'),
              style: const TextStyle(color: AppColors.textLabel),
              textAlign: TextAlign.center,
            ),
          );
        }

        final payments = snapshot.data ?? [];
        if (payments.isEmpty) {
          return _ModernCard(
            child: Text(
              _localizedText(t, 'لا توجد دفعات لهذا العقد', 'No payments for this contract'),
              style: const TextStyle(color: AppColors.textLabel),
              textAlign: TextAlign.center,
            ),
          );
        }

        bool isPaid(ContractPayment p) =>
            p.gatewayStatus == 'paid' || (p.gatewayStatus == null && p.dueDate == null);

        final latePayments = payments.where((p) => p.isLate).toList()
          ..sort((a, b) => (a.dueDate ?? '').compareTo(b.dueDate ?? ''));

        final scheduledPayments = payments.where((p) => !isPaid(p) && !p.isLate).toList()
          ..sort((a, b) => (a.dueDate ?? '').compareTo(b.dueDate ?? ''));

        final paidPayments = payments.where(isPaid).toList()
          ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (latePayments.isNotEmpty) ...[
              ExpandableSection(
                title: _localizedText(t, 'الدفعات المتأخرة', 'Late Payments'),
                count: latePayments.length,
                color: Colors.red.shade700,
                children: [_buildGroupCard(theme, t, latePayments)],
              ),
              const SizedBox(height: 16),
            ],
            if (scheduledPayments.isNotEmpty) ...[
              ExpandableSection(
                title: _localizedText(t, 'الدفعات المجدولة', 'Scheduled Payments'),
                count: scheduledPayments.length,
                color: Colors.blue.shade700,
                children: [_buildGroupCard(theme, t, scheduledPayments)],
              ),
              const SizedBox(height: 16),
            ],
            if (paidPayments.isNotEmpty)
              ExpandableSection(
                title: _localizedText(t, 'الدفعات المدفوعة', 'Paid Payments'),
                count: paidPayments.length,
                color: Colors.green.shade700,
                initiallyExpanded: false,
                children: [_buildGroupCard(theme, t, paidPayments)],
              ),
          ],
        );
      },
    );
  }

  Widget _buildGroupCard(
    ThemeData theme,
    AppLocalizations t,
    List<ContractPayment> list,
  ) {
    return _ModernCard(
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.neutral200),
            _buildPaymentRow(theme, t, list[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentRow(
    ThemeData theme,
    AppLocalizations t,
    ContractPayment p,
  ) {
    final status = _statusOf(t, p);
    final dateLabel = p.dueDate != null
        ? '${_localizedText(t, 'استحقاق', 'Due')}: ${p.dueDate}'
        : p.paymentDate;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.amount.toStringAsFixed(3)} ${_localizedText(t, 'د.ك', 'KWD')}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_methodLabel(t, p.paymentMethod)} • $dateLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textLabel,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(label: status.label, color: status.color),
        ],
      ),
    );
  }
}

class _ModernCard extends StatelessWidget {
  final Widget child;

  const _ModernCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _ModernInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool singleLineValue;
  final ThemeData theme;

  const _ModernInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.singleLineValue = false,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textLabel,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: singleLineValue ? 1 : null,
                  overflow: singleLineValue ? TextOverflow.ellipsis : null,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
