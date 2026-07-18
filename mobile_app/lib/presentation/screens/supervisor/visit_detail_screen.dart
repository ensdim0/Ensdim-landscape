// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/domain/entities/contract.dart';
import 'package:bustan_amari/domain/entities/visit.dart';
import 'package:bustan_amari/domain/entities/visit_photo.dart';
import 'package:bustan_amari/presentation/providers/supervisor_provider.dart';
import 'package:bustan_amari/presentation/screens/supervisor/finish_visit_screen.dart';
import 'package:bustan_amari/presentation/widgets/empty_state.dart';
import 'package:bustan_amari/presentation/widgets/custom_app_bar.dart';
import 'package:bustan_amari/presentation/widgets/error_view.dart';
import 'package:bustan_amari/presentation/widgets/status_chip.dart';
import 'package:bustan_amari/presentation/widgets/supervisor_notes_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:bustan_amari/core/utils/date_formatter.dart' as date_fmt;

bool _isVideoPath(String path) {
  final normalized = path.split('?').first.toLowerCase();
  return normalized.endsWith('.mp4') ||
      normalized.endsWith('.mov') ||
      normalized.endsWith('.m4v') ||
      normalized.endsWith('.avi') ||
      normalized.endsWith('.webm') ||
      normalized.endsWith('.mkv');
}

class VisitDetailScreen extends StatefulWidget {
  final Visit visit;
  final Contract contract;

  const VisitDetailScreen({
    super.key,
    required this.visit,
    required this.contract,
  });

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  String _tr(AppLocalizations t, String key, String fallback) {
    final value = t.tr(key);
    return value == key ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SupervisorProvider>();
      provider.loadTasks(
        contractId: widget.contract.id,
        visitId: widget.visit.id,
      );
      provider.loadTaskExecutions(widget.visit.id);
      provider.loadVisitPhotos(widget.visit.id);
      provider.loadVisitComments(widget.visit.id);
      provider.loadSupervisorNotes(widget.visit.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: CustomAppBar(
        title: t.tr('visitDetails'),
        backButtonBackgroundColor: Colors.transparent,
      ),
      bottomNavigationBar: Consumer<SupervisorProvider>(
        builder: (context, provider, _) {
          final visit = provider.selectedVisit ?? widget.visit;
          if (visit.isCompleted || visit.isCancelled) {
            return const SizedBox.shrink();
          }
          return _buildBottomActions(context, theme, t, visit, provider);
        },
      ),
      body: Consumer<SupervisorProvider>(
        builder: (context, provider, _) {
          final visit = provider.selectedVisit ?? widget.visit;
          final completedTasks = provider.tasks
              .where((task) => task.isCompleted || task.isVerified)
              .length;
          final totalTasks = provider.tasks.length;
          final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
          final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;
          final hasBottomControls = !(visit.isCompleted || visit.isCancelled);
          final controlsBaseHeight = hasBottomControls
              ? (visit.isInProgress && screenWidth < 380 ? 162.0 : 112.0)
              : 20.0;
          final bodyBottomPadding = controlsBaseHeight + bottomSafeInset;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              bodyBottomPadding,
            ),
            children: [
              _buildVisitHeaderCard(theme, t, visit),
              const SizedBox(height: 16),

              // Supervisor Notes
              SupervisorNotesWidget(
                visitId: widget.visit.id,
                contractId: widget.contract.id,
                notes: provider.supervisorNotes,
                isLoading: provider.isActionLoading,
                onAddNote: (content, visibility) => provider.addSupervisorNote(
                  visitId: widget.visit.id,
                  contractId: widget.contract.id,
                  content: content,
                  visibility: visibility,
                ),
                onUpdateNote: (noteId, content, visibility) =>
                    provider.updateSupervisorNote(
                      noteId: noteId,
                      content: content,
                      visibility: visibility,
                    ),
                onDeleteNote: (noteId) => provider.deleteSupervisorNote(noteId),
              ),
              const SizedBox(height: 16),

              if (visit.isCompleted) ...[
                _buildCompletionInfoCard(theme, t, visit, provider.visitPhotos),
                const SizedBox(height: 16),
              ],

              if (provider.visitComments.isNotEmpty) ...[
                _buildClientCommentsCard(theme, t, provider),
                const SizedBox(height: 16),
              ],

              _buildSectionTitle(theme, t.tr('tasks')),
              _buildTasksSummaryCard(
                theme,
                t,
                completedTasks,
                totalTasks,
                progress,
              ),
              const SizedBox(height: 12),
              _buildTasksSection(context, theme, t, provider, visit),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 4, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildVisitHeaderCard(
    ThemeData theme,
    AppLocalizations t,
    Visit visit,
  ) {
    final statusLabel = switch (visit.status) {
      'completed' => t.locale.languageCode == 'ar' ? 'مكتملة' : 'Completed',
      'planned' => t.locale.languageCode == 'ar' ? 'لم تكتمل' : 'Not completed',
      'in_progress' =>
        t.locale.languageCode == 'ar' ? 'لم تكتمل' : 'Not completed',
      'cancelled' =>
        t.locale.languageCode == 'ar' ? 'لم تكتمل' : 'Not completed',
      _ => visit.status,
    };

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_note_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr(t, 'visitDate', 'تاريخ الزيارة'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        visit.visitDate.split('T').first,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusChip.visitStatus(visit.status, statusLabel),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.confirmation_num_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${t.tr('contractCode')}: ${widget.contract.code}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (visit.notes != null && visit.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.25,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  visit.notes!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTasksSummaryCard(
    ThemeData theme,
    AppLocalizations t,
    int completedTasks,
    int totalTasks,
    double progress,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '$completedTasks/$totalTasks ${_tr(t, 'completedTasks', 'مهام مكتملة')}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    ThemeData theme,
    AppLocalizations t,
    Visit visit,
    SupervisorProvider provider,
  ) {
    final isNarrow = MediaQuery.of(context).size.width < 380;
    final primaryStyle = FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
    );
    final secondaryStyle = OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.6)),
    );

    if (visit.isPlanned) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: provider.isActionLoading
                  ? null
                  : () => _updateStatus(
                      context,
                      t,
                      visit.id,
                      'in_progress',
                      t.tr('confirmStartVisit'),
                    ),
              style: primaryStyle,
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text(
                t.tr('startVisit'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (visit.isInProgress) {
      if (isNarrow) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: provider.isActionLoading
                        ? null
                        : () => _handleFinishVisit(context, t, visit, provider),
                    style: primaryStyle,
                    icon: const Icon(Icons.check_circle_rounded, size: 24),
                    label: Text(
                      t.tr('finishVisit'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: provider.isActionLoading
                        ? null
                        : () => _updateStatus(
                            context,
                            t,
                            visit.id,
                            'cancelled',
                            t.tr('confirmCancelVisit'),
                          ),
                    style: secondaryStyle,
                    icon: const Icon(Icons.cancel_outlined, size: 24),
                    label: Text(
                      t.tr('cancelVisit'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: provider.isActionLoading
                        ? null
                        : () => _handleFinishVisit(context, t, visit, provider),
                    style: primaryStyle,
                    icon: const Icon(Icons.check_circle_rounded, size: 24),
                    label: Text(
                      t.tr('finishVisit'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: provider.isActionLoading
                        ? null
                        : () => _updateStatus(
                            context,
                            t,
                            visit.id,
                            'cancelled',
                            t.tr('confirmCancelVisit'),
                          ),
                    style: secondaryStyle,
                    icon: const Icon(Icons.cancel_outlined, size: 24),
                    label: Text(
                      t.tr('cancelVisit'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _handleFinishVisit(
    BuildContext context,
    AppLocalizations t,
    Visit visit,
    SupervisorProvider provider,
  ) async {
    // Check if all tasks are completed
    if (!provider.allTasksCompleted) {
      final shouldFinish = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t.tr('tasksIncomplete')),
          content: Text(t.tr('tasksIncompleteMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.tr('completeTasks')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.tr('finishVisit')),
            ),
          ],
        ),
      );
      if (shouldFinish != true) return;
    }

    // Navigate to finish visit screen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: FinishVisitScreen(visit: visit),
        ),
      ),
    );

    if (result == true && context.mounted) {
      // Refresh tasks list after completion
      provider.loadTasks(
        contractId: widget.contract.id,
        visitId: widget.visit.id,
      );
      provider.loadVisitPhotos(visit.id);
    }
  }

  Widget _buildTasksSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations t,
    SupervisorProvider provider,
    Visit visit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.status == DataStatus.loading && provider.tasks.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (provider.status == DataStatus.error && provider.tasks.isEmpty)
          ErrorView(
            message: t.tr('errorLoadingData'),
            onRetry: () => provider.loadTasks(
              contractId: widget.contract.id,
              visitId: widget.visit.id,
            ),
          )
        else if (provider.tasks.isEmpty)
          EmptyState(icon: Icons.assignment_outlined, message: t.tr('noTasks'))
        else
          ...provider.tasks.map((task) {
            final isDone = task.isCompleted || task.isVerified;
            final canToggle = task.isPending &&
                    (visit.isInProgress || visit.isCompleted) ||
                task.isCompleted && visit.isInProgress;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: CheckboxListTile(
                value: isDone,
                onChanged: canToggle
                    ? (_) => _onTaskCheckChanged(
                        context,
                        t,
                        task.id,
                        provider,
                        isDone,
                      )
                    : null,
                title: Text(
                  task.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? theme.colorScheme.onSurfaceVariant : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  isDone ? t.tr('completedStatus') : t.tr('pendingStatus'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDone ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                activeColor: Colors.green,
                controlAffinity: ListTileControlAffinity.leading,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                dense: MediaQuery.of(context).size.width < 350,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCompletionInfoCard(
    ThemeData theme,
    AppLocalizations t,
    Visit visit,
    List<VisitPhoto> visitPhotos,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  t.tr('visitCompleted'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            if (visit.summary != null && visit.summary!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${t.tr('visitSummary')}:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              if (_isSummaryLink(visit.summary!))
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openSummaryLink(visit.summary!),
                    icon: const Icon(Icons.link_rounded),
                    label: Text(_tr(t, 'عرض الملخص', 'View summary')),
                  ),
                )
              else
                Text(visit.summary!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Text(
              '${t.tr('visitPhotos')}:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (visitPhotos.isEmpty)
              Text(
                t.tr('noPhotos'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: visitPhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final photo = visitPhotos[index];
                    final isVideo = _isVideoPath(photo.photoPath);
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          _openVisitPhotosViewer(context, visitPhotos, index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            if (isVideo)
                              Container(
                                width: 84,
                                height: 84,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.videocam_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            else
                              Image.network(
                                photo.photoPath,
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 84,
                                  height: 84,
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  isVideo
                                      ? Icons.play_circle_fill_rounded
                                      : Icons.open_in_full_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (visitPhotos.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                t.tr('tapToPreview'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (visit.hasGps) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openVisitLocation(visit),
                  icon: const Icon(Icons.location_on_rounded),
                  label: Text(
                    t.locale.languageCode == 'ar'
                        ? 'عرض الموقع'
                        : 'View location',
                  ),
                ),
              ),
            ],
            if (visit.completedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${t.locale.languageCode == 'ar' ? 'اكتملت في' : 'Completed at'}: ${_formatDateTime(visit.completedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientCommentsCard(
    ThemeData theme,
    AppLocalizations t,
    SupervisorProvider provider,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.feedback_outlined,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  t.tr('clientComments'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...provider.visitComments.map(
              (comment) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName ?? t.tr('client'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(comment.comment, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}/$month/$day ${date_fmt.formatTime(local)}';
  }

  Future<void> _onTaskCheckChanged(
    BuildContext context,
    AppLocalizations t,
    String taskId,
    SupervisorProvider provider,
    bool wasCompleted,
  ) async {
    final success = await provider.toggleTaskStatus(taskId);

    if (context.mounted) {
      final message = success
          ? (wasCompleted ? t.tr('taskUncompleted') : t.tr('taskCompleted'))
          : t.tr('errorExecutingTask');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? const Color(0xFF30461F) : Colors.red,
        ),
      );
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    AppLocalizations t,
    String visitId,
    String newStatus,
    String confirmMessage,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.tr('confirm')),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.tr('confirm')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<SupervisorProvider>();
      final success = await provider.updateVisitStatus(
        visitId: visitId,
        status: newStatus,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? t.tr('visitUpdated') : t.tr('errorUpdatingVisit'),
            ),
            backgroundColor: success ? const Color(0xFF30461F) : Colors.red,
          ),
        );
      }
    }
  }

  void _openVisitPhotosViewer(
    BuildContext context,
    List<VisitPhoto> photos,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VisitPhotosViewerScreen(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _openVisitLocation(Visit visit) async {
    if (!visit.hasGps) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${visit.gpsLat},${visit.gpsLng}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _isSummaryLink(String summary) {
    final uri = Uri.tryParse(summary.trim());
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  Future<void> _openSummaryLink(String summary) async {
    final uri = Uri.tryParse(summary.trim());
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _VisitPhotosViewerScreen extends StatefulWidget {
  final List<VisitPhoto> photos;
  final int initialIndex;

  const _VisitPhotosViewerScreen({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_VisitPhotosViewerScreen> createState() =>
      _VisitPhotosViewerScreenState();
}

class _VisitPhotosViewerScreenState extends State<_VisitPhotosViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  int? _videoIndex;
  bool _videoInitFailed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initVideoForIndex(widget.initialIndex);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _initVideoForIndex(int index) {
    _videoController?.dispose();
    _videoController = null;
    _videoIndex = null;
    _videoInitFailed = false;

    final media = widget.photos[index];
    if (!_isVideoPath(media.photoPath)) return;

    final uri = Uri.tryParse(media.photoPath);
    if (uri == null) {
      setState(() {
        _videoIndex = index;
        _videoInitFailed = true;
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;
    _videoIndex = index;
    controller.setLooping(true);
    controller
        .initialize()
        .then((_) {
          if (!mounted || _videoController != controller) return;
          controller.play();
          setState(() {});
        })
        .catchError((_) {
          if (!mounted || _videoController != controller) return;
          setState(() {
            _videoInitFailed = true;
          });
        });
  }

  Future<void> _togglePlayPause() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) setState(() {});
  }

  Future<void> _seekBySeconds(int seconds) async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final current = controller.value.position;
    final duration = controller.value.duration;
    var target = current + Duration(seconds: seconds);

    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;

    await controller.seekTo(target);
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildVideoView() {
    if (_videoInitFailed) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 56,
        ),
      );
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _togglePlayPause,
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final duration = value.duration;
            final position = value.position > duration
                ? duration
                : value.position;

            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white54,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () => _seekBySeconds(-10),
                            constraints: const BoxConstraints.tightFor(
                              width: 40,
                              height: 40,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.replay_10_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: _togglePlayPause,
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              value.isPlaying
                                  ? Icons.pause_circle_rounded
                                  : Icons.play_circle_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => _seekBySeconds(10),
                            constraints: const BoxConstraints.tightFor(
                              width: 40,
                              height: 40,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.forward_10_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${t.tr('visitPhotos')} (${_currentIndex + 1}/${widget.photos.length})',
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          _initVideoForIndex(index);
        },
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          if (_isVideoPath(photo.photoPath)) {
            if (_videoIndex != index) {
              return const Center(
                child: Icon(
                  Icons.videocam_rounded,
                  color: Colors.white70,
                  size: 56,
                ),
              );
            }

            return _buildVideoView();
          }

          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                photo.photoPath,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 56,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
