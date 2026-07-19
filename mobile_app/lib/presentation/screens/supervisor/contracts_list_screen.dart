// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/domain/entities/app_user.dart';
import 'package:ensdim_landscape/domain/entities/contract.dart';
import 'package:ensdim_landscape/domain/entities/zone.dart';
import 'package:ensdim_landscape/presentation/providers/supervisor_provider.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/contract_detail_screen.dart';
import 'package:ensdim_landscape/presentation/widgets/empty_state.dart';
import 'package:ensdim_landscape/presentation/widgets/error_view.dart';
import 'package:ensdim_landscape/presentation/widgets/status_chip.dart';

class ContractsListScreen extends StatefulWidget {
  final AppUser user;

  const ContractsListScreen({super.key, required this.user});

  @override
  State<ContractsListScreen> createState() => _ContractsListScreenState();
}

class _ContractsListScreenState extends State<ContractsListScreen> {
  String _searchQuery = '';
  String? _selectedZoneId;
  String? _selectedStatus;
  bool _lateOnly = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SupervisorProvider>();
    if (provider.contracts.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.loadContracts();
      });
    }
  }

  String _statusLabel(String status, AppLocalizations t) {
    return switch (status) {
      'active' => t.tr('statusActive'),
      'pending' => t.tr('statusPending'),
      'terminated' => t.tr('statusTerminated'),
      'expired' => t.tr('statusExpired'),
      _ => status,
    };
  }

  void _showFilterBottomSheet(BuildContext context, SupervisorProvider provider) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    String? tempZoneId = _selectedZoneId;
    String? tempStatus = _selectedStatus;
    bool tempLateOnly = _lateOnly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.neutral300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.locale.languageCode == 'ar' ? 'تصفية العقود' : 'Contract Filters',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempZoneId = null;
                            tempStatus = null;
                            tempLateOnly = false;
                          });
                        },
                        child: Text(
                          t.tr('clearFilters'),
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (provider.assignedZones.isNotEmpty) ...[
                    Text(
                      t.tr('contractsFilterByArea'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: tempZoneId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.neutral200),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(t.tr('contractsFilterAll')),
                        ),
                        ...provider.assignedZones.map(
                          (zone) => DropdownMenuItem<String?>(
                            value: zone.id,
                            child: Text(zone.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          tempZoneId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    t.tr('filterByStatus'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: t.tr('contractsFilterAll'),
                        selected: tempStatus == null,
                        onTap: () => setModalState(() => tempStatus = null),
                      ),
                      ...['active', 'pending'].map(
                        (status) => _FilterChip(
                          label: _statusLabel(status, t),
                          selected: tempStatus == status,
                          onTap: () => setModalState(() => tempStatus = status),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t.locale.languageCode == 'ar' ? 'حالة الدفعات' : 'Payment Status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: t.locale.languageCode == 'ar'
                            ? 'فيه دفعات متأخرة'
                            : 'Has late payments',
                        selected: tempLateOnly,
                        onTap: () => setModalState(() => tempLateOnly = !tempLateOnly),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(t.tr('cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedZoneId = tempZoneId;
                              _selectedStatus = tempStatus;
                              _lateOnly = tempLateOnly;
                            });
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(t.tr('confirm')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveFiltersRow(BuildContext context, SupervisorProvider provider, AppLocalizations t) {
    final hasActiveFilters = _selectedZoneId != null || _selectedStatus != null || _lateOnly;
    if (!hasActiveFilters) return const SizedBox.shrink();

    Zone? zone;
    if (_selectedZoneId != null) {
      for (final z in provider.assignedZones) {
        if (z.id == _selectedZoneId) {
          zone = z;
          break;
        }
      }
    }

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (zone != null && zone.name.isNotEmpty)
            _ActiveFilterTag(
              label: zone.name,
              onClear: () => setState(() => _selectedZoneId = null),
            ),
          if (_selectedStatus != null)
            _ActiveFilterTag(
              label: _statusLabel(_selectedStatus!, t),
              onClear: () => setState(() => _selectedStatus = null),
            ),
          if (_lateOnly)
            _ActiveFilterTag(
              label: t.locale.languageCode == 'ar' ? 'فيه دفعات متأخرة' : 'Has late payments',
              onClear: () => setState(() => _lateOnly = false),
            ),
          _ClearAllButton(
            onPressed: () {
              setState(() {
                _selectedZoneId = null;
                _selectedStatus = null;
                _lateOnly = false;
              });
            },
            label: t.tr('clearFilters'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;

    return Consumer<SupervisorProvider>(
      builder: (context, provider, _) {
        if (provider.status == DataStatus.loading &&
            provider.contracts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.status == DataStatus.error && provider.contracts.isEmpty) {
          return ErrorView(
            message: t.tr('errorLoadingData'),
            onRetry: () => provider.loadContracts(),
          );
        }

        final availableZoneIds = provider.assignedZones
            .map((z) => z.id)
            .toSet();
        if (_selectedZoneId != null &&
            !availableZoneIds.contains(_selectedZoneId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _selectedZoneId = null);
          });
        }

        final byZone = _selectedZoneId == null
            ? provider.contracts
            : provider.contracts
                  .where((c) => c.zoneId == _selectedZoneId)
                  .toList();

        final byStatus = _selectedStatus == null
            ? byZone
            : byZone.where((c) => c.status == _selectedStatus).toList();

        final byLate = !_lateOnly
            ? byStatus
            : byStatus.where((c) => provider.lateContractIds.contains(c.id)).toList();

        final filtered = _searchQuery.isEmpty
            ? byLate
            : byLate.where((c) {
                final q = _searchQuery.toLowerCase();
                return c.code.toLowerCase().contains(q) ||
                    (c.contractUserName?.toLowerCase().contains(q) ?? false) ||
                    (c.contractUserPhone?.toLowerCase().contains(q) ?? false) ||
                    (c.clientName?.toLowerCase().contains(q) ?? false) ||
                    (c.clientPhone?.toLowerCase().contains(q) ?? false) ||
                    (c.addressDetails?.toLowerCase().contains(q) ?? false);
              }).toList();

        return Column(
          children: [
            // Modern Search bar
            Container(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: t.tr('searchContracts'),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary700,
                        ),
                        filled: true,
                        fillColor: AppColors.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.neutral200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.neutral200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary700,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: screenWidth < 360 ? 12 : 16,
                          horizontal: 20,
                        ),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _FilterButton(
                    isActive: _selectedZoneId != null || _selectedStatus != null || _lateOnly,
                    padding: screenWidth < 360 ? 12.0 : 16.0,
                    onTap: () => _showFilterBottomSheet(context, provider),
                  ),
                ],
              ),
            ),

            _buildActiveFiltersRow(context, provider, t),

            // Contracts list
            Expanded(
              child: filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.description_rounded,
                      message: t.tr('noContracts'),
                      onRetry: () => provider.loadContracts(),
                    )
                  : RefreshIndicator(
                      onRefresh: () => provider.loadContracts(),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(horizontalPadding),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _ContractCard(
                          contract: filtered[index],
                          theme: theme,
                          t: t,
                          isLate: provider.lateContractIds.contains(filtered[index].id),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final double padding;

  const _FilterButton({
    required this.isActive,
    required this.onTap,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary100 : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary700 : AppColors.neutral200,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.tune_rounded,
              color: AppColors.primary700,
            ),
            if (isActive)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterTag extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _ActiveFilterTag({
    required this.label,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.primary700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearAllButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _ClearAllButton({
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.primary700,
      backgroundColor: AppColors.cardBackground,
      side: BorderSide(
        color: selected ? AppColors.primary700 : AppColors.neutral300,
      ),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? AppColors.cardBackground : AppColors.textLabel,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Contract contract;
  final ThemeData theme;
  final AppLocalizations t;
  final bool isLate;

  const _ContractCard({
    required this.contract,
    required this.theme,
    required this.t,
    this.isLate = false,
  });

  String _statusLabel(String status) {
    return switch (status) {
      'active' => t.tr('statusActive'),
      'pending' => t.tr('statusPending'),
      'terminated' => t.tr('statusTerminated'),
      'expired' => t.tr('statusExpired'),
      _ => status,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'active' => Colors.green,
      'pending' => Colors.orange,
      'terminated' => Colors.red,
      'expired' => Colors.grey,
      _ => Colors.grey,
    };
  }

  String? get _displayPhone =>
      contract.clientPhone ?? contract.contractUserPhone;

  String _formatShortAddress(Contract c, bool isArabic) {
    final line = c.lineName?.trim() ?? '';
    final zone = c.zoneName?.trim() ?? '';
    final block = c.blockNumber?.trim() ?? '';
    final street = c.street?.trim() ?? '';
    final avenue = c.avenue?.trim() ?? '';
    final house = c.house?.trim() ?? '';
    final details = c.addressDetails?.trim() ?? '';

    if (isArabic) {
      final parts = <String>[];
      if (zone.isNotEmpty) {
        parts.add(zone);
      } else if (line.isNotEmpty)
        parts.add(line);

      final abbr = <String>[];
      if (block.isNotEmpty) abbr.add('ق $block');
      if (street.isNotEmpty) abbr.add('ش $street');
      if (avenue.isNotEmpty) abbr.add('ج $avenue');
      if (house.isNotEmpty) abbr.add('م $house');

      if (abbr.isNotEmpty) parts.add(abbr.join(' '));

      if (parts.isEmpty && details.isNotEmpty) return details;
      return parts.join('، ');
    } else {
      final parts = <String>[];
      if (zone.isNotEmpty) {
        parts.add(zone);
      } else if (line.isNotEmpty)
        parts.add(line);

      final abbr = <String>[];
      if (block.isNotEmpty) abbr.add('B $block');
      if (street.isNotEmpty) abbr.add('St $street');
      if (avenue.isNotEmpty) abbr.add('Av $avenue');
      if (house.isNotEmpty) abbr.add('H $house');

      if (abbr.isNotEmpty) parts.add(abbr.join(' • '));

      if (parts.isEmpty && details.isNotEmpty) return details;
      return parts.join(' • ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPalms =
        contract.palmInfo != null && contract.palmInfo!.isPalm;
    final int totalPalms = (() {
      if (!hasPalms) return 0;
      final isBaladi = (contract.palmInfo?.species ?? 'baladi') == 'baladi';
      final stats = isBaladi
          ? contract.palmInfo!.baladi
          : contract.palmInfo!.washingtonia;
      return stats.largeProductive +
          stats.largeNonProductive +
          stats.smallProductive +
          stats.smallNonProductive;
    })();
    final bool isArabic = t.locale.languageCode == 'ar';
    final String totalLabel = isArabic ? 'إجمالي النخيل' : 'Total Palms';
    final String shortAddress = _formatShortAddress(contract, isArabic);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<SupervisorProvider>(),
                  child: ContractDetailScreen(contract: contract),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.request_page_rounded,
                        color: AppColors.primary700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contract.code,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              StatusChip(
                                label: _statusLabel(contract.status),
                                color: _statusColor(contract.status),
                              ),
                              if (isLate)
                                StatusChip(
                                  label: t.locale.languageCode == 'ar'
                                      ? 'دفعة متأخرة'
                                      : 'Late payment',
                                  color: Colors.red,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: AppColors.textLabel,
                    ),
                  ],
                ),

                if (contract.clientName != null ||
                    _displayPhone != null ||
                    shortAddress.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, thickness: 1, color: AppColors.neutral200),
                  const SizedBox(height: 16),
                ],

                // Middle Info Section
                if (contract.clientName != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: AppColors.primary700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          contract.clientName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLabel,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (shortAddress.isNotEmpty) const SizedBox(height: 10),
                ],

                if (_displayPhone != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        size: 18,
                        color: AppColors.primary700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _displayPhone!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLabel,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (shortAddress.isNotEmpty) const SizedBox(height: 10),
                ],

                if (shortAddress.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: AppColors.primary700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shortAddress,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLabel,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                // Show total palms in list if available
                if (hasPalms && totalPalms > 0) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.nature_rounded,
                        size: 18,
                        color: AppColors.primary700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$totalLabel: $totalPalms',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLabel,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Bottom Date Section wrapped in a soft container
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        size: 16,
                        color: AppColors.textLabel,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${contract.startDate.split('T').first}  —  ${contract.endDate.split('T').first}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.textLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


