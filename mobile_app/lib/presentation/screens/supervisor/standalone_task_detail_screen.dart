// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/domain/entities/standalone_task.dart';
import 'package:bustan_amari/domain/entities/contract.dart';
import 'package:bustan_amari/presentation/providers/supervisor_provider.dart';
import 'package:bustan_amari/presentation/widgets/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:bustan_amari/core/utils/date_formatter.dart' as date_fmt;

class StandaloneTaskDetailScreen extends StatefulWidget {
  final StandaloneTask task;
  final SupervisorProvider provider;

  const StandaloneTaskDetailScreen({
    super.key,
    required this.task,
    required this.provider,
  });

  @override
  State<StandaloneTaskDetailScreen> createState() =>
      _StandaloneTaskDetailScreenState();
}

class _StandaloneTaskDetailScreenState
    extends State<StandaloneTaskDetailScreen> {
  late String _currentStatus;
  bool _isUpdatingStatus = false;
  String? _localSupervisorReport;
  String? _localNotes;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.task.status;
    _localSupervisorReport = widget.task.supervisorReport ?? widget.task.notes;
    _localNotes = widget.task.notes;
    // If the provider doesn't have the linked contract loaded, fetch it so we can show its code.
    if (widget.task.contractId != null) {
      final exists = widget.provider.contracts.any(
        (c) => c.id == (widget.task.contractId ?? ''),
      );
      if (!exists) {
        widget.provider
            .selectContract(widget.task.contractId!)
            .then((_) {
              if (mounted) setState(() {});
            })
            .catchError((_) {});
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isUpdatingStatus || newStatus == _currentStatus) return;

    final t = AppLocalizations.of(context);
    final previousStatus = _currentStatus;

    // If marking completed or cancelled, require supervisor report.
    String? requiredReport;
    if (newStatus == 'completed' || newStatus == 'cancelled') {
      requiredReport = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text(t.tr('supervisorNotes')),
            content: SizedBox(
              width: double.maxFinite,
              child: TextField(
                controller: controller,
                maxLines: 6,
                decoration: InputDecoration(hintText: t.tr('taskNotesHint')),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: Text(t.tr('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(t.tr('taskNotesHint'))),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(text);
                },
                child: Text(t.tr('saveChanges')),
              ),
            ],
          );
        },
      );

      // If user cancelled dialog, don't proceed with status change
      if (requiredReport == null || requiredReport.trim().isEmpty) return;
    }

    setState(() {
      _isUpdatingStatus = true;
      _currentStatus = newStatus;
    });

    try {
      await widget.provider.updateStandaloneTaskStatus(
        taskId: widget.task.id,
        status: newStatus,
        supervisorReport: requiredReport,
      );
      if (!mounted) return;
      if (requiredReport != null) {
        setState(() => _localSupervisorReport = requiredReport);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.tr('taskUpdated')),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _currentStatus = previousStatus);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.tr('errorUpdating')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case 'pending':
        return AppColors.warning;
      case 'in_progress':
        return AppColors.info;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textLabel;
    }
  }

  IconData _getStatusIcon() {
    switch (_currentStatus) {
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.play_circle_filled;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusLabel(BuildContext context) {
    final t = AppLocalizations.of(context);
    switch (_currentStatus) {
      case 'pending':
        return t.tr('pending');
      case 'in_progress':
        return t.tr('inProgress');
      case 'completed':
        return t.tr('completed');
      case 'cancelled':
        return t.tr('cancelled');
      default:
        return t.tr(_currentStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Resolve line/zone: prefer task-specific, fallback to linked contract
    String? displayLine = widget.task.lineName?.trim();
    String? displayZone = widget.task.zoneName?.trim();
    if ((displayLine == null || displayLine.isEmpty) &&
        widget.task.contractId != null) {
      final c = widget.provider.contracts.firstWhere(
        (c) => c.id == (widget.task.contractId ?? ''),
        orElse: () => Contract(
          id: '',
          code: '',
          zoneId: null,
          lineId: null,
          status: '',
          startDate: '',
          endDate: '',
          totalValue: 0.0,
          createdAt: '',
        ),
      );
      displayLine = displayLine ?? c.lineName;
      displayZone = displayZone ?? c.zoneName;
    }

    // Resolve contract code to show instead of raw id. If not present in the
    // cached list, prefer provider.selectedContract (loaded on demand above).
    String displayContractCode = '—';
    if (widget.task.contractId != null) {
      final cc = widget.provider.contracts.firstWhere(
        (c) => c.id == (widget.task.contractId ?? ''),
        orElse: () => Contract(
          id: '',
          code: '',
          zoneId: null,
          lineId: null,
          status: '',
          startDate: '',
          endDate: '',
          totalValue: 0.0,
          createdAt: '',
        ),
      );

      if (cc.code != null && cc.code.isNotEmpty) {
        displayContractCode = cc.code;
      } else if (widget.provider.selectedContract != null &&
          widget.provider.selectedContract!.id == widget.task.contractId &&
          (widget.provider.selectedContract!.code.isNotEmpty)) {
        displayContractCode = widget.provider.selectedContract!.code;
      } else {
        displayContractCode = '—';
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: t.tr('taskDetails'),
        showBackButton: false,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16, 16, 16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Header Card with Gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getStatusColor().withValues(alpha: 0.8),
                    _getStatusColor().withValues(alpha: 0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getStatusIcon(),
                        color: _getStatusColor(),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.task.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(context),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Status Update Section
            Card(
              elevation: 0,
              color: AppColors.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          t.tr('changeStatus'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusButton(
                          label: t.tr('pending'),
                          icon: Icons.schedule,
                          color: AppColors.warning,
                          isSelected: _currentStatus == 'pending',
                          isLoading: _isUpdatingStatus,
                          onPressed: () => _updateStatus('pending'),
                        ),
                        _StatusButton(
                          label: t.tr('inProgress'),
                          icon: Icons.play_circle_filled,
                          color: AppColors.info,
                          isSelected: _currentStatus == 'in_progress',
                          isLoading: _isUpdatingStatus,
                          onPressed: () => _updateStatus('in_progress'),
                        ),
                        _StatusButton(
                          label: t.tr('completed'),
                          icon: Icons.check_circle,
                          color: AppColors.success,
                          isSelected: _currentStatus == 'completed',
                          isLoading: _isUpdatingStatus,
                          onPressed: () => _updateStatus('completed'),
                        ),
                        _StatusButton(
                          label: t.tr('cancelled'),
                          icon: Icons.cancel,
                          color: AppColors.error,
                          isSelected: _currentStatus == 'cancelled',
                          isLoading: _isUpdatingStatus,
                          onPressed: () => _updateStatus('cancelled'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Description Section
            if (widget.task.description != null &&
                widget.task.description!.isNotEmpty) ...[
              Card(
                elevation: 0,
                color: AppColors.cardBackground,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.tr('description'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.task.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Address Section (includes Line & Zone)
            if ((widget.task.address != null &&
                    widget.task.address!.isNotEmpty) ||
                (displayLine != null && displayLine.isNotEmpty) ||
                (displayZone != null && displayZone.isNotEmpty)) ...[
              Card(
                elevation: 0,
                color: AppColors.cardBackground,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.tr('address'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (displayLine != null && displayLine.isNotEmpty) ...[
                        _DetailRow(
                          icon: Icons.alt_route_rounded,
                          label: t.tr('lineName'),
                          value: displayLine,
                        ),
                      ],

                      if (displayZone != null && displayZone.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.place,
                          label: t.tr('zone'),
                          value: displayZone,
                        ),
                      ],

                      if (widget.task.address != null &&
                          widget.task.address!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.neutral200),
                          ),
                          child: Text(
                            widget.task.address!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Client Info Section
            Card(
              elevation: 0,
              color: AppColors.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          t.tr('clientInfo'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.person,
                      label: t.tr('name'),
                      value: widget.task.clientName ?? t.tr('notSpecified'),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.phone,
                      label: t.tr('phone'),
                      value: widget.task.clientPhone ?? t.tr('notSpecified'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Contract Info Section (if linked)
            if (widget.task.contractId != null) ...[
              Card(
                elevation: 0,
                color: AppColors.cardBackground,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.link, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            t.tr('contractDetails'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.confirmation_number,
                        label: t.tr('contractCode'),
                        value: displayContractCode,
                      ),
                      if (widget.task.cost != null) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.attach_money,
                          label: t.tr('taskCost'),
                          value: widget.task.cost!.toStringAsFixed(2),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            const SizedBox(height: 24),

            // Task Details Section
            Card(
              elevation: 0,
              color: AppColors.cardBackground,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          t.tr('taskDetails'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.calendar_today,
                      label: t.tr('date'),
                      value: _formatTaskDateString(widget.task.taskDate),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.add_circle,
                      label: t.tr('createdAt'),
                      value: widget.task.createdAt.split('T')[0],
                    ),
                    if (widget.task.updatedAt != null) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.update,
                        label: t.tr('lastUpdate'),
                        value: widget.task.updatedAt!.split('T')[0],
                      ),
                    ],
                    // Line & Address are shown in the Address card above to avoid duplication.
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Supervisor Report Section
            if (_localSupervisorReport != null &&
                _localSupervisorReport!.isNotEmpty)
              Card(
                elevation: 0,
                color: AppColors.cardBackground,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            t.tr('supervisorNotes'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.neutral200),
                        ),
                        child: Text(
                          _localSupervisorReport!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Additional Notes (ملاحظات إضافية)
            if (_localNotes != null && _localNotes!.isNotEmpty)
              Card(
                elevation: 0,
                color: AppColors.cardBackground,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.note_alt,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.tr('additionalNotes'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.neutral200),
                        ),
                        child: Text(
                          _localNotes!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

String _formatTaskDateString(String value) {
  if (value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed != null) {
    final local = parsed.toLocal();
    return '${DateFormat('dd/MM/yyyy').format(local)} ${date_fmt.formatTime(local)}';
  }
  final datePart = value.split(' ').first.split('T').first;
  return datePart;
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onPressed;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : AppColors.neutral200,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                isLoading ? '...' : label,
                style: TextStyle(
                  color: color.withValues(alpha: isLoading ? 0.7 : 1),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textPlaceholder,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
