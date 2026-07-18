import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/domain/entities/app_user.dart';
import 'package:bustan_amari/domain/entities/standalone_task.dart';
import 'package:bustan_amari/domain/entities/contract.dart';
import 'package:bustan_amari/presentation/providers/supervisor_provider.dart';
import 'package:bustan_amari/presentation/widgets/empty_state.dart';
import 'package:bustan_amari/presentation/screens/supervisor/standalone_task_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:bustan_amari/core/utils/date_formatter.dart' as date_fmt;

class StandaloneTasksListScreen extends StatefulWidget {
  final AppUser user;

  const StandaloneTasksListScreen({super.key, required this.user});

  @override
  State<StandaloneTasksListScreen> createState() =>
      _StandaloneTasksListScreenState();
}

class _StandaloneTasksListScreenState extends State<StandaloneTasksListScreen> {
  static const List<String> _statusOptions = [
    'all',
    'pending',
    'in_progress',
    'completed',
    'cancelled',
  ];

  String _selectedStatus = 'all';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<SupervisorProvider>();
      prov.loadStandaloneTasks();
      prov.loadContracts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<SupervisorProvider>(
        builder: (context, provider, _) {
          final now = DateTime.now();

          final filteredTasks = provider.standaloneTasks.where((task) {
            final matchesStatus =
                _selectedStatus == 'all' || task.status == _selectedStatus;
            final matchesDate =
                _selectedDate == null ||
                _normalizeDate(task.taskDate) == _dateKey(_selectedDate!);

            // Completed tasks should only be visible if completed within last 24 hours
            bool showCompleted = true;
            if (task.status == 'completed') {
              DateTime? completedAt;
              if ((task.updatedAt ?? '').trim().isNotEmpty) {
                completedAt = DateTime.tryParse(task.updatedAt!);
              }
              completedAt ??= DateTime.tryParse(task.createdAt);
              completedAt ??= DateTime.tryParse(task.taskDate);

              if (completedAt == null) {
                showCompleted = false;
              } else {
                final diff = now.difference(completedAt.toLocal());
                showCompleted = diff.inHours <= 24;
              }
            }

            // If 'all' is selected, include pending and in-progress always,
            // but only include completed when they are recent (24h)
            if (_selectedStatus == 'all' &&
                task.status == 'completed' &&
                !showCompleted) {
              return false;
            }

            // If user explicitly selected 'completed', still enforce 24h window
            if (_selectedStatus == 'completed' &&
                task.status == 'completed' &&
                !showCompleted) {
              return false;
            }

            return matchesStatus && matchesDate;
          }).toList();

          if (provider.isLoadingStandaloneTasks) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    t.tr('loading'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          if (provider.standaloneTasks.isEmpty) {
            return EmptyState(
              message: t.tr('noTasksYet'),
              icon: Icons.check_circle_outline,
            );
          }

          if (filteredTasks.isEmpty) {
            return _buildFilteredEmptyState(
              context,
              t,
              onClearFilters: () {
                setState(() {
                  _selectedStatus = 'all';
                  _selectedDate = null;
                });
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadStandaloneTasks();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              children: [
                _TaskFilterBar(
                  selectedStatus: _selectedStatus,
                  selectedDate: _selectedDate,
                  onStatusTap: () => _openStatusSheet(context),
                  onDateTap: () => _pickDate(context),
                  onClear: _selectedStatus == 'all' && _selectedDate == null
                      ? null
                      : () {
                          setState(() {
                            _selectedStatus = 'all';
                            _selectedDate = null;
                          });
                        },
                ),
                const SizedBox(height: 8),
                ...filteredTasks.map(
                  (task) => _TaskCard(
                    task: task,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StandaloneTaskDetailScreen(
                            task: task,
                            provider: provider,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: AppLocalizations.of(context).tr('selectDate'),
      cancelText: AppLocalizations.of(context).tr('cancel'),
      confirmText: AppLocalizations.of(context).tr('confirm'),
    );

    if (!mounted || picked == null) return;

    setState(() {
      _selectedDate = DateUtils.dateOnly(picked);
    });
  }

  void _openStatusSheet(BuildContext context) {
    final t = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 380;
            final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: sheetHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.flag_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t.tr('filterByStatus'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: _selectedStatus == 'all'
                              ? null
                              : () {
                                  setState(() => _selectedStatus = 'all');
                                  Navigator.pop(sheetContext);
                                },
                          child: Text(t.tr('clearFilters')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isCompact ? 1 : 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: isCompact ? 5.3 : 3.6,
                        ),
                        itemCount: _statusOptions.length,
                        itemBuilder: (context, index) {
                          final status = _statusOptions[index];
                          final isSelected = _selectedStatus == status;

                          return _StatusChoiceTile(
                            label: _statusLabel(t, status),
                            selected: isSelected,
                            onTap: () {
                              setState(() => _selectedStatus = status);
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilteredEmptyState(
    BuildContext context,
    AppLocalizations t, {
    required VoidCallback onClearFilters,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_alt_off_outlined,
                  size: 56,
                  color: AppColors.textPlaceholder,
                ),
                const SizedBox(height: 16),
                Text(
                  t.tr('noFilteredTasks'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.tr('tryChangeFilters'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(t.tr('clearFilters')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations t, String status) {
    switch (status) {
      case 'all':
        return t.tr('contractsFilterAll');
      case 'pending':
        return t.tr('pending');
      case 'in_progress':
        return t.tr('inProgress');
      case 'completed':
        return t.tr('completed');
      case 'cancelled':
        return t.tr('cancelled');
      default:
        return status;
    }
  }

  String _normalizeDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return _dateKey(parsed);
    }

    final datePart = value.split(' ').first.split('T').first;
    return datePart;
  }

  String _dateKey(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    return '${normalized.year.toString().padLeft(4, '0')}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }
}

String _formatTaskDateString(String value) {
  if (value.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed != null) {
    final local = parsed.toLocal();
    return '${DateFormat('dd/MM/yyyy').format(local)} ${date_fmt.formatTime(local)}';
  }
  // Fallback to date part
  final datePart = value.split(' ').first.split('T').first;
  return datePart;
}

class _TaskFilterBar extends StatelessWidget {
  final String selectedStatus;
  final DateTime? selectedDate;
  final VoidCallback onStatusTap;
  final VoidCallback onDateTap;
  final VoidCallback? onClear;

  const _TaskFilterBar({
    required this.selectedStatus,
    required this.selectedDate,
    required this.onStatusTap,
    required this.onDateTap,
    required this.onClear,
  });


  String _dateLabel(DateTime date) {
    final d = DateUtils.dateOnly(date);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasFilters = selectedStatus != 'all' || selectedDate != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.tr('taskFilters'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (hasFilters)
                TextButton(
                  onPressed: onClear,
                  child: Text(t.tr('clearFilters')),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FilterFieldTile(
                  title: t.tr('taskStatus'),
                  value: selectedStatus == 'all'
                      ? t.tr('contractsFilterAll')
                      : (selectedStatus == 'pending'
                            ? t.tr('pending')
                            : selectedStatus == 'in_progress'
                            ? t.tr('inProgress')
                            : selectedStatus == 'completed'
                            ? t.tr('completed')
                            : selectedStatus == 'cancelled'
                            ? t.tr('cancelled')
                            : selectedStatus),
                  onTap: onStatusTap,
                  accentColor: AppColors.primary,
                  isActive: selectedStatus != 'all',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterFieldTile(
                  title: t.tr('date'),
                  value: selectedDate == null
                      ? t.tr('contractsFilterAll')
                      : _dateLabel(selectedDate!),
                  onTap: onDateTap,
                  accentColor: AppColors.info,
                  isActive: selectedDate != null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterFieldTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isActive;

  const _FilterFieldTile({
    required this.title,
    required this.value,
    required this.onTap,
    required this.accentColor,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? accentColor.withValues(alpha: 0.28)
                  : AppColors.neutral200,
            ),
          ),
          child: Row(
            children: [
              // No leading icon — clearer, text-first filter button
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.expand_more,
                size: 18,
                color: AppColors.textPlaceholder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.neutral200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textPlaceholder,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final StandaloneTask task;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  Color _getStatusColor() {
    switch (task.status) {
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
    switch (task.status) {
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
    switch (task.status) {
      case 'pending':
        return t.tr('pending');
      case 'in_progress':
        return t.tr('inProgress');
      case 'completed':
        return t.tr('completed');
      case 'cancelled':
        return t.tr('cancelled');
      default:
        return task.status;
    }
  }

  String _buildLineZoneLabel(AppLocalizations t, String? line, String? zone) {
    final hasLine = line != null && line.isNotEmpty;
    final hasZone = zone != null && zone.isNotEmpty;

    if (hasLine && hasZone) {
      return '${t.tr('lineName')}: $line • ${t.tr('zone')}: $zone';
    }

    if (hasLine) return '${t.tr('lineName')}: $line';
    if (hasZone) return '${t.tr('zone')}: $zone';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor();
    final prov = Provider.of<SupervisorProvider>(context, listen: false);
    final t = AppLocalizations.of(context);

    // Resolve line/zone: prefer task-specific, fallback to linked contract
    String? displayLine = task.lineName?.trim();
    String? displayZone = task.zoneName?.trim();
    if ((displayLine == null || displayLine.isEmpty) &&
        task.contractId != null) {
      final c = prov.contracts.firstWhere(
        (c) => c.id == (task.contractId ?? ''),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.neutral200, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and status
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(),
                                size: 14,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getStatusLabel(context),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        task.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Divider
              Divider(height: 1, color: AppColors.neutral200),
              // Footer with meta info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppColors.textPlaceholder,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatTaskDateString(task.taskDate),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (task.contractId != null) ...[
                          Icon(
                            Icons.article_outlined,
                            size: 14,
                            color: AppColors.textPlaceholder,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              Provider.of<SupervisorProvider>(
                                        context,
                                        listen: false,
                                      ).contracts
                                      .firstWhere(
                                        (c) => c.id == (task.contractId ?? ''),
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
                                      )
                                      .code
                                      .isNotEmpty
                                  ? Provider.of<SupervisorProvider>(
                                          context,
                                          listen: false,
                                        ).contracts
                                        .firstWhere(
                                          (c) =>
                                              c.id == (task.contractId ?? ''),
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
                                        )
                                        .code
                                  : '—',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textPlaceholder,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else if (task.clientName != null) ...[
                          Icon(
                            Icons.person,
                            size: 14,
                            color: AppColors.textPlaceholder,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              task.clientName!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textPlaceholder,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (task.clientPhone != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: AppColors.textPlaceholder,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            task.clientPhone!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textPlaceholder,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (task.address != null && task.address!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.textPlaceholder,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              task.address!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textPlaceholder,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((displayLine != null && displayLine.isNotEmpty) ||
                        (displayZone != null && displayZone.isNotEmpty)) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.alt_route_rounded,
                            size: 14,
                            color: AppColors.textPlaceholder,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _buildLineZoneLabel(t, displayLine, displayZone),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textPlaceholder,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
