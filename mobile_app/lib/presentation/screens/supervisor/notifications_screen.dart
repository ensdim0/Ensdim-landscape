import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/domain/entities/app_notification.dart';
import 'package:bustan_amari/domain/repositories/i_notification_repository.dart';
import 'package:bustan_amari/infrastructure/di/service_locator.dart';
import 'package:bustan_amari/presentation/providers/supervisor_provider.dart';
import 'package:bustan_amari/domain/entities/contract.dart';
import 'package:bustan_amari/domain/entities/visit.dart';
import 'package:bustan_amari/presentation/screens/supervisor/standalone_task_detail_screen.dart';
import 'package:bustan_amari/presentation/screens/supervisor/visit_detail_screen.dart';
import 'package:bustan_amari/presentation/widgets/custom_app_bar.dart';

class NotificationsScreen extends StatefulWidget {
  final INotificationRepository repository;
  final SupervisorProvider? supervisorProvider;

  const NotificationsScreen({
    super.key,
    required this.repository,
    this.supervisorProvider,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repository.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _loading = false;
      });
      await widget.repository.markAllAsRead();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onTapNotification(AppNotification n) async {
    final type = n.meta['type'] as String?;

    try {
      if (type == 'standalone_task_assigned') {
        final taskId = n.meta['task_id'] as String?;
        if (taskId == null) return;
        final provider = widget.supervisorProvider;
        if (provider == null || !mounted) return;

        final task = await ServiceLocator.instance.supervisorRepository
            .getStandaloneTask(taskId);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StandaloneTaskDetailScreen(task: task, provider: provider),
          ),
        );
      } else if (type == 'client_comment' || type == 'supervisor_note') {
        final visitId    = n.meta['visit_id']    as String?;
        final contractId = n.meta['contract_id'] as String?;
        final provider   = widget.supervisorProvider;
        if (visitId == null || contractId == null || provider == null || !mounted) return;

        final Visit visit = await ServiceLocator.instance.supervisorRepository
            .getVisit(visitId);
        final Contract contract = await ServiceLocator.instance.supervisorRepository
            .getContract(contractId);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: VisitDetailScreen(visit: visit, contract: contract),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: l10n.tr('notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmpty(context, l10n)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16, 16, 16,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _NotificationTile(
                      n: _notifications[i],
                      l10n: l10n,
                      onTap: () => _onTapNotification(_notifications[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 64, color: AppColors.textLabel),
          const SizedBox(height: 12),
          Text(
            l10n.tr('noNotifications'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textLabel,
                ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification n;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  const _NotificationTile({
    required this.n,
    required this.l10n,
    this.onTap,
  });

  bool get _isTappable {
    final type = n.meta['type'] as String?;
    if (type == 'standalone_task_assigned') return n.meta['task_id'] != null;
    if (type == 'client_comment' || type == 'supervisor_note') {
      return n.meta['visit_id'] != null && n.meta['contract_id'] != null;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeAgo = _formatTime(n.createdAt);

    return GestureDetector(
      onTap: _isTappable ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: n.isRead ? AppColors.cardBackground : AppColors.primary100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.isRead ? AppColors.neutral200 : AppColors.primary200,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: n.isRead
                    ? AppColors.neutral200
                    : AppColors.primary700.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_rounded,
                size: 20,
                color: n.isRead ? AppColors.textLabel : AppColors.primary700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight:
                          n.isRead ? FontWeight.w500 : FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (n.body != null && n.body!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      n.body!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textLabel,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        timeAgo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textLabel,
                          fontSize: 11,
                        ),
                      ),
                      if (_isTappable) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: AppColors.primary700,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!n.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: AppColors.primary700,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.tr('justNow');
    if (diff.inMinutes < 60) {
      return l10n.trArgs('minutesAgo', diff.inMinutes.toString());
    }
    if (diff.inHours < 24) {
      return l10n.trArgs('hoursAgo', diff.inHours.toString());
    }
    if (diff.inDays < 30) {
      return l10n.trArgs('daysAgo', diff.inDays.toString());
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
