import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task_assignee.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task_item.dart';
import 'package:ensdim_landscape/domain/entities/contract.dart';
import 'package:ensdim_landscape/presentation/providers/supervisor_provider.dart';
import 'package:ensdim_landscape/presentation/widgets/custom_app_bar.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/standalone_task_visit_action_screen.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/standalone_task_payment_sheet.dart';
import 'package:intl/intl.dart';
import 'package:ensdim_landscape/core/utils/date_formatter.dart' as date_fmt;

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
  RealtimeChannel? _taskChannel;
  RealtimeChannel? _itemsChannel;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.provider.loadStandaloneTaskDetails(widget.task.id);
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
    });
    _subscribeRealtime();
  }

  // Any team member acting from their own device flips the same row this
  // screen is showing — subscribing here means everyone watching this task
  // sees it update within a second, with no manual refresh.
  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    _taskChannel = client
        .channel('standalone_task_detail_${widget.task.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'standalone_tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.task.id,
          ),
          callback: (_) => widget.provider.refreshStandaloneTask(widget.task.id),
        )
        .subscribe();

    _itemsChannel = client
        .channel('standalone_task_detail_items_${widget.task.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'standalone_task_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'task_id',
            value: widget.task.id,
          ),
          callback: (_) => widget.provider.refreshStandaloneTask(widget.task.id),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _taskChannel?.unsubscribe();
    _itemsChannel?.unsubscribe();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
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

  IconData _statusIcon(String status) {
    switch (status) {
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

  String _statusLabel(AppLocalizations t, String status) {
    switch (status) {
      case 'pending':
        return t.tr('pending');
      case 'in_progress':
        return t.tr('inProgress');
      case 'completed':
        return t.tr('completed');
      case 'cancelled':
        return t.tr('cancelled');
      default:
        return t.tr(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    // This screen is reached via Navigator.push, which in this app's shell
    // isn't always a descendant of wherever SupervisorProvider is created —
    // so we listen to the instance passed in explicitly (widget.provider)
    // instead of looking one up via Provider.of/Consumer, matching how this
    // screen already received it before this rewrite.
    final provider = widget.provider;
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final task = provider.standaloneTasks.firstWhere(
          (item) => item.id == widget.task.id,
          orElse: () => widget.task,
        );
        final assignees = provider.standaloneTaskAssignees;
        final items = provider.standaloneTaskItems;
        final allItemsCompleted = provider.standaloneTaskItemsAllCompleted;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: CustomAppBar(
            title: t.tr('taskDetails'),
            backButtonBackgroundColor: Colors.transparent,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(context, t, task),
                const SizedBox(height: 20),
                _buildTeamCard(context, t, assignees),
                const SizedBox(height: 16),
                _buildChecklistCard(context, t, provider, task, items),
                const SizedBox(height: 16),
                if (task.visitStartedAt != null || task.visitEndedAt != null) ...[
                  _buildVisitCard(context, t, task),
                  const SizedBox(height: 16),
                ],
                if (task.description != null && task.description!.isNotEmpty) ...[
                  _buildInfoCard(
                    context,
                    icon: Icons.description,
                    title: t.tr('description'),
                    child: Text(
                      task.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if ((task.address != null && task.address!.isNotEmpty) ||
                    (task.lineName != null && task.lineName!.isNotEmpty) ||
                    (task.zoneName != null && task.zoneName!.isNotEmpty)) ...[
                  _buildAddressCard(context, t, task),
                  const SizedBox(height: 16),
                ],
                _buildClientCard(context, t, task),
                const SizedBox(height: 16),
                if (task.contractId != null) ...[
                  _buildContractCard(context, t, provider, task),
                  const SizedBox(height: 16),
                ],
                _buildMetaCard(context, t, task),
                if (task.notes != null && task.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    icon: Icons.note_alt,
                    title: t.tr('additionalNotes'),
                    child: Text(
                      task.notes!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                if (task.supervisorReport != null &&
                    task.supervisorReport!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    icon: Icons.note,
                    title: t.tr('supervisorNotes'),
                    child: Text(
                      task.supervisorReport!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
          bottomNavigationBar: _buildActionBar(
            context,
            t,
            provider,
            task,
            allItemsCompleted,
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context, AppLocalizations t, StandaloneTask task) {
    final theme = Theme.of(context);
    final color = _statusColor(task.status);
    final isClosed = task.status == 'completed' && task.paymentStatus == 'paid';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.4)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_statusIcon(task.status), color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(t, task.status),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (task.status == 'completed')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isClosed ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t.tr(isClosed ? 'taskClosedLabel' : 'awaitingPayment'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isClosed ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(
    BuildContext context,
    AppLocalizations t,
    List<StandaloneTaskAssignee> assignees,
  ) {
    final supervisorsCount = assignees.where((a) => a.isSupervisor).length;
    // Worker assignment isn't offered from the creation screen anymore —
    // this only ever shows for tasks created before that change.
    final workersCount = assignees.where((a) => a.isWorker).length;

    return _buildInfoCard(
      context,
      icon: Icons.groups_rounded,
      title: t.tr('standaloneTaskTeam'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _TeamChip(
            icon: Icons.badge_rounded,
            label: '$supervisorsCount ${t.tr('supervisor')}',
            color: AppColors.primary,
          ),
          if (workersCount > 0)
            _TeamChip(
              icon: Icons.engineering_rounded,
              label: '$workersCount ${t.tr('teamWorkersLabel')}',
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(
    BuildContext context,
    AppLocalizations t,
    SupervisorProvider provider,
    StandaloneTask task,
    List<StandaloneTaskItem> items,
  ) {
    final theme = Theme.of(context);
    final canToggle = task.status == 'in_progress';
    final completedCount = items.where((i) => i.isCompleted).length;
    final progress = items.isEmpty ? 0.0 : completedCount / items.length;

    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  t.tr('checklistTitle'),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (items.isNotEmpty) ...[
                  const Spacer(),
                  Text(
                    '$completedCount/${items.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.neutral200,
                  valueColor: AlwaysStoppedAnimation(AppColors.success),
                ),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (item) => CheckboxListTile(
                  value: item.isCompleted,
                  onChanged: canToggle
                      ? (checked) => provider.toggleStandaloneTaskItem(
                          itemId: item.id,
                          completed: checked ?? false,
                        )
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: item.isCompleted
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t.tr('noChecklistItems'),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPlaceholder),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCard(BuildContext context, AppLocalizations t, StandaloneTask task) {
    final theme = Theme.of(context);

    return _buildInfoCard(
      context,
      icon: Icons.location_on_rounded,
      title: t.tr('recordGps'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.visitStartedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${t.tr('startedAtLabel')}: ${_formatDateTimeString(task.visitStartedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          if (task.visitEndedAt != null)
            Text(
              '${t.tr('endedAtLabel')}: ${_formatDateTimeString(task.visitEndedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          if (task.paymentConfirmedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '${t.tr('paymentConfirmedLabel')}: ${_formatDateTimeString(task.paymentConfirmedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, AppLocalizations t, StandaloneTask task) {
    return _buildInfoCard(
      context,
      icon: Icons.location_on,
      title: t.tr('address'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.lineName != null && task.lineName!.isNotEmpty)
            _DetailRow(icon: Icons.alt_route_rounded, label: t.tr('lineName'), value: task.lineName!),
          if (task.zoneName != null && task.zoneName!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailRow(icon: Icons.place, label: t.tr('zone'), value: task.zoneName!),
          ],
          if (task.address != null && task.address!.isNotEmpty) ...[
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
                task.address!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientCard(BuildContext context, AppLocalizations t, StandaloneTask task) {
    return _buildInfoCard(
      context,
      icon: Icons.person,
      title: t.tr('clientInfo'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(icon: Icons.person, label: t.tr('name'), value: task.clientName ?? t.tr('notSpecified')),
          const SizedBox(height: 12),
          _DetailRow(icon: Icons.phone, label: t.tr('phone'), value: task.clientPhone ?? t.tr('notSpecified')),
        ],
      ),
    );
  }

  Widget _buildContractCard(
    BuildContext context,
    AppLocalizations t,
    SupervisorProvider provider,
    StandaloneTask task,
  ) {
    final contract = provider.contracts.firstWhere(
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

    return _buildInfoCard(
      context,
      icon: Icons.link,
      title: t.tr('contractDetails'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: Icons.confirmation_number,
            label: t.tr('contractCode'),
            value: contract.code.isNotEmpty ? contract.code : '—',
          ),
          if (task.cost != null) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.attach_money,
              label: t.tr('taskCost'),
              value: task.cost!.toStringAsFixed(2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaCard(BuildContext context, AppLocalizations t, StandaloneTask task) {
    return _buildInfoCard(
      context,
      icon: Icons.info,
      title: t.tr('taskDetails'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: Icons.calendar_today,
            label: t.tr('date'),
            value: _formatTaskDateString(task.taskDate),
          ),
          const SizedBox(height: 12),
          _DetailRow(icon: Icons.add_circle, label: t.tr('createdAt'), value: task.createdAt.split('T').first),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget? _buildActionBar(
    BuildContext context,
    AppLocalizations t,
    SupervisorProvider provider,
    StandaloneTask task,
    bool allItemsCompleted,
  ) {
    if (task.status == 'cancelled') return null;
    if (task.status == 'completed' && task.paymentStatus == 'paid') return null;

    final loading = provider.isActionLoading || _cancelling;

    Widget primaryButton;
    if (task.status == 'pending') {
      primaryButton = FilledButton.icon(
        onPressed: loading ? null : () => _openVisitAction(context, task, StandaloneTaskVisitPhase.start),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(t.tr('startVisit')),
      );
    } else if (task.status == 'in_progress') {
      primaryButton = FilledButton.icon(
        onPressed: (loading || !allItemsCompleted)
            ? null
            : () => _openVisitAction(context, task, StandaloneTaskVisitPhase.end),
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: Text(t.tr('finishVisit')),
      );
    } else {
      // completed + unpaid
      primaryButton = FilledButton.icon(
        onPressed: loading ? null : () => _openPaymentSheet(context, task),
        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
        icon: const Icon(Icons.payments_rounded),
        label: Text(t.tr('confirmPayment')),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.status == 'in_progress' && !allItemsCompleted)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t.tr('visitEndBlockedPendingItems'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                ),
              ),
            Row(
              children: [
                if (task.status == 'pending' || task.status == 'in_progress') ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : () => _confirmCancel(context, task),
                      child: Text(t.tr('cancelTask')),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: SizedBox(height: 48, child: primaryButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVisitAction(
    BuildContext context,
    StandaloneTask task,
    StandaloneTaskVisitPhase phase,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StandaloneTaskVisitActionScreen(
          task: task,
          phase: phase,
          provider: widget.provider,
        ),
      ),
    );
  }

  Future<void> _openPaymentSheet(BuildContext context, StandaloneTask task) async {
    await showStandaloneTaskPaymentSheet(context, task, widget.provider);
  }

  Future<void> _confirmCancel(BuildContext context, StandaloneTask task) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController();

    final reason = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.tr('confirmCancelTask')),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              maxLines: 4,
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
              child: Text(t.tr('confirm')),
            ),
          ],
        );
      },
    );

    if (reason == null || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await widget.provider.updateStandaloneTaskStatus(
        taskId: task.id,
        status: 'cancelled',
        supervisorReport: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr('taskUpdated')), backgroundColor: AppColors.success),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.tr('errorUpdating')), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
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

String _formatDateTimeString(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  return '${DateFormat('dd/MM/yyyy').format(local)} ${date_fmt.formatTime(local)}';
}

class _TeamChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TeamChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

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
