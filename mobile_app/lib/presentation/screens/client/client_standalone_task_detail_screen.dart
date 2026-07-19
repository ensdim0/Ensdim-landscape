import 'package:flutter/material.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task.dart';
import 'package:ensdim_landscape/presentation/widgets/custom_app_bar.dart';
import 'package:ensdim_landscape/core/utils/date_formatter.dart' as date_fmt;

class ClientStandaloneTaskDetailScreen extends StatelessWidget {
  final StandaloneTask task;
  final String contractCode;

  const ClientStandaloneTaskDetailScreen({
    super.key,
    required this.task,
    required this.contractCode,
  });

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

  String _getStatusLabel(AppLocalizations t) {
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final statusColor = _getStatusColor();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: t.tr('taskDetails'),
        backButtonBackgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16, 16, 16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.task_alt_rounded, color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              contractCode,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.textPlaceholder,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _getStatusLabel(t),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniChip(
                        icon: Icons.calendar_today_outlined,
                        label: _formatDate(task.taskDate),
                      ),
                      if (_hasTime(task.taskDate))
                        _MiniChip(
                          icon: Icons.access_time_rounded,
                          label: _formatTime(task.taskDate),
                        ),
                      if (task.cost != null)
                        _MiniChip(
                          icon: Icons.attach_money,
                          label: task.cost!.toStringAsFixed(2),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: t.tr('taskDetails'),
            children: [
              _DetailRow(
                icon: Icons.confirmation_number_outlined,
                label: t.tr('contractCode'),
                value: contractCode,
              ),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: t.tr('date'),
                value: _formatDate(task.taskDate),
                secondaryValue: _hasTime(task.taskDate)
                    ? _formatTime(task.taskDate)
                    : null,
              ),
              _DetailRow(
                icon: Icons.access_time,
                label: t.tr('createdAt'),
                value: _formatDate(task.createdAt),
                secondaryValue: _hasTime(task.createdAt)
                    ? _formatTime(task.createdAt)
                    : null,
              ),
              if ((task.updatedAt ?? '').trim().isNotEmpty)
                _DetailRow(
                  icon: Icons.update,
                  label: t.tr('lastUpdate'),
                  value: _formatDate(task.updatedAt!),
                  secondaryValue: _hasTime(task.updatedAt!)
                      ? _formatTime(task.updatedAt!)
                      : null,
                ),
              if (task.cost != null)
                _DetailRow(
                  icon: Icons.attach_money,
                  label: t.tr('taskCost'),
                  value: task.cost!.toStringAsFixed(2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: t.tr('description'),
            children: [
              Text(
                (task.description ?? '').trim().isEmpty
                    ? t.tr('noData')
                    : task.description!.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: t.tr('address'),
            children: [
              Text(
                (task.address ?? '').trim().isEmpty
                    ? t.tr('noData')
                    : task.address!.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: t.tr('clientInfo'),
            children: [
              _DetailRow(
                icon: Icons.person_outline,
                label: t.tr('name'),
                value: (task.clientName ?? '').trim().isEmpty
                    ? t.tr('noData')
                    : task.clientName!.trim(),
              ),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: t.tr('phone'),
                value: (task.clientPhone ?? '').trim().isEmpty
                    ? t.tr('noData')
                    : task.clientPhone!.trim(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if ((task.notes ?? '').trim().isNotEmpty)
            _SectionCard(
              title: t.tr('notes'),
              children: [
                Text(
                  task.notes!.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── date/time helpers ─────────────────────────────────────────
  DateTime? _parse(String value) {
    try {
      final s = value.contains(' ') && !value.contains('T')
          ? value.replaceFirst(' ', 'T')
          : value;
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String value) {
    final dt = _parse(value);
    if (dt == null) return value.split('T').first.split(' ').first;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  String _formatTime(String value) {
    final dt = _parse(value);
    if (dt == null) return '';
    return date_fmt.formatTime(dt);
  }

  bool _hasTime(String value) =>
      value.contains('T') ||
      (value.contains(' ') && RegExp(r'\d{2}:\d{2}').hasMatch(value));
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textPlaceholder),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
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
  final String? secondaryValue;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.secondaryValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textPlaceholder,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    if (secondaryValue != null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 1,
                        height: 14,
                        color: AppColors.textPlaceholder.withValues(alpha: 0.4),
                      ),
                      Text(
                        secondaryValue!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPlaceholder,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
