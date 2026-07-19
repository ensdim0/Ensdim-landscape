import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/domain/entities/contract.dart';
import 'package:ensdim_landscape/domain/entities/contract_task.dart';
import 'package:ensdim_landscape/domain/entities/visit.dart';
import 'package:ensdim_landscape/presentation/providers/supervisor_provider.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/visit_detail_screen.dart';
import 'package:ensdim_landscape/presentation/widgets/custom_app_bar.dart';
import 'package:ensdim_landscape/presentation/widgets/empty_state.dart';
import 'package:ensdim_landscape/presentation/widgets/error_view.dart';
import 'package:ensdim_landscape/presentation/widgets/status_chip.dart';

class VisitsListScreen extends StatefulWidget {
  final Contract contract;

  const VisitsListScreen({super.key, required this.contract});

  @override
  State<VisitsListScreen> createState() => _VisitsListScreenState();
}

class _VisitsListScreenState extends State<VisitsListScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SupervisorProvider>();
      provider.loadVisits(widget.contract.id);
      provider.loadVisitTasksOverview(widget.contract.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;

    return Scaffold(
      appBar: CustomAppBar(
        title: t.tr('visits'),
        backButtonBackgroundColor: Colors.transparent,
      ),
      body: Consumer<SupervisorProvider>(
        builder: (context, provider, _) {
          if (provider.status == DataStatus.loading &&
              provider.visits.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.status == DataStatus.error && provider.visits.isEmpty) {
            return ErrorView(
              message: t.tr('errorLoadingData'),
              onRetry: () => provider.loadVisits(widget.contract.id),
            );
          }

          if (provider.visits.isEmpty) {
            return EmptyState(
              icon: Icons.event_note_outlined,
              message: t.tr('noVisits'),
              onRetry: () => provider.loadVisits(widget.contract.id),
            );
          }

          final groups = _applySearchFilter(_buildGroups(provider.visits, t));
          final visibleGroups = groups
              .where((g) => g.visits.isNotEmpty)
              .toList();

          return Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  8,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: _translate(t, 'searchVisits', 'ابحث في الزيارات'),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: screenWidth < 360 ? 12 : 16,
                      horizontal: 20,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await provider.loadVisits(widget.contract.id);
                    await provider.loadVisitTasksOverview(widget.contract.id);
                  },
                  child: visibleGroups.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _translate(
                                  t,
                                  'noVisits',
                                  'لا توجد زيارات مطابقة للبحث',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            horizontalPadding,
                            horizontalPadding,
                            horizontalPadding +
                                MediaQuery.of(context).padding.bottom,
                          ),
                          itemCount: visibleGroups.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _VisitGroupSection(
                            group: visibleGroups[index],
                            theme: theme,
                            t: t,
                            contract: widget.contract,
                            provider: provider,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _translate(AppLocalizations t, String key, String fallback) {
    final value = t.tr(key);
    return value == key ? fallback : value;
  }

  List<_VisitGroup> _applySearchFilter(List<_VisitGroup> groups) {
    if (_searchQuery.isEmpty) return groups;

    return groups.map((group) {
      final filteredVisits = group.visits.where((visit) {
        final haystack = [
          group.title,
          group.description ?? '',
          visit.title ?? '',
          visit.notes ?? '',
          visit.description ?? '',
          visit.visitDate,
          visit.status,
        ].join(' ').toLowerCase();

        return haystack.contains(_searchQuery);
      }).toList();

      return _VisitGroup(
        key: group.key,
        title: group.title,
        description: group.description,
        visits: filteredVisits,
      );
    }).toList();
  }

  List<_VisitGroup> _buildGroups(List<Visit> visits, AppLocalizations t) {
    final terms = widget.contract.terms.where((term) => !term.isExcluded).toList()
      ..sort((a, b) => a.activationOrder.compareTo(b.activationOrder));

    if (terms.isEmpty) {
      final fallback = <String, List<Visit>>{};
      final meta = <String, ({String title, String? description})>{};

      for (final visit in visits) {
        final key = visit.groupingKey;
        fallback.putIfAbsent(key, () => []).add(visit);
        final notes = (visit.notes ?? '').trim();
        final description = (visit.description ?? '').trim();
        final title = (visit.title ?? '').trim();
        final displayTitle = notes.isNotEmpty
            ? notes
            : description.isNotEmpty
            ? description
            : title.isNotEmpty
            ? title
            : t.tr('generalVisitsItem');
        meta[key] = (
          title: displayTitle,
          description: notes.isNotEmpty
              ? notes
              : description.isNotEmpty
              ? description
              : null,
        );
      }

      return fallback.entries.map((entry) {
        final itemMeta = meta[entry.key]!;
        return _VisitGroup(
          key: entry.key,
          title: itemMeta.title,
          description: itemMeta.description,
          visits: entry.value,
        );
      }).toList();
    }

    final usedVisitIds = <String>{};
    final groups = <_VisitGroup>[];

    for (var index = 0; index < terms.length; index++) {
      final term = terms[index];
      final termContent = term.content.trim();

      // Mirror client app logic: match visits by title == term content
      final matchedVisits = visits.where((visit) {
        if (usedVisitIds.contains(visit.id)) return false;
        return (visit.title ?? '').trim() == termContent;
      }).toList();

      usedVisitIds.addAll(matchedVisits.map((visit) => visit.id));

      groups.add(
        _VisitGroup(
          key: 'term_$index',
          title: termContent.isNotEmpty
              ? termContent
              : '${t.tr('generalVisitsItem')} ${index + 1}',
          description: null,
          visits: matchedVisits,
        ),
      );
    }

    final unmatchedVisits = visits
        .where((visit) => !usedVisitIds.contains(visit.id))
        .toList();

    if (unmatchedVisits.isNotEmpty) {
      groups.add(
        _VisitGroup(
          key: 'other_visits',
          title: t.tr('otherVisitsItem'),
          description: null,
          visits: unmatchedVisits,
        ),
      );
    }

    return groups;
  }
}

class _VisitGroup {
  final String key;
  final String title;
  final String? description;
  final List<Visit> visits;

  const _VisitGroup({
    required this.key,
    required this.title,
    required this.description,
    required this.visits,
  });
}

class _VisitGroupSection extends StatelessWidget {
  final _VisitGroup group;
  final ThemeData theme;
  final AppLocalizations t;
  final Contract contract;
  final SupervisorProvider provider;

  const _VisitGroupSection({
    required this.group,
    required this.theme,
    required this.t,
    required this.contract,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final sortedVisits = [...group.visits]
      ..sort((a, b) => b.visitDate.compareTo(a.visitDate));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.topic_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          group.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.description != null && group.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                group.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${t.tr('visitsCount')}: ${group.visits.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        children: sortedVisits
            .map(
              (visit) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VisitCard(
                  visit: visit,
                  theme: theme,
                  t: t,
                  contract: contract,
                  tasks: provider.tasksForVisit(visit.id),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final Visit visit;
  final ThemeData theme;
  final AppLocalizations t;
  final Contract contract;
  final List<ContractTask> tasks;

  const _VisitCard({
    required this.visit,
    required this.theme,
    required this.t,
    required this.contract,
    required this.tasks,
  });

  String _statusLabel(String status) {
    return switch (status) {
      'completed' => t.locale.languageCode == 'ar' ? 'مكتملة' : 'Completed',
      'planned' => t.locale.languageCode == 'ar' ? 'لم تكتمل' : 'Not completed',
      'in_progress' =>
        t.locale.languageCode == 'ar' ? 'لم تكتمل' : 'Not completed',
      'cancelled' =>
        t.locale.languageCode == 'ar' ? 'لم تكتمل' : 'Not completed',
      _ => status,
    };
  }

  String _formatVisitDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '---';
    final date = DateTime.tryParse(iso);
    if (date == null) return '---';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final completedTasks = tasks
        .where((task) => task.isCompleted || task.isVerified)
        .length;

    final title = visit.notes?.trim().isNotEmpty == true
        ? visit.notes!.trim()
        : (visit.description?.trim().isNotEmpty == true
              ? visit.description!.trim()
              : (visit.title?.trim().isNotEmpty == true
                    ? visit.title!.trim()
                    : t.tr('visitDetails')));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
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
            context.read<SupervisorProvider>().selectVisit(visit);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<SupervisorProvider>(),
                  child: VisitDetailScreen(visit: visit, contract: contract),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          StatusChip.visitStatus(
                            visit.status,
                            _statusLabel(visit.status),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatVisitDate(visit.visitDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (tasks.isNotEmpty)
                      Text(
                        '$completedTasks/${tasks.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                if (visit.completedAt != null &&
                    visit.completedAt!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: const Color(0xFF15803d),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.locale.languageCode == 'ar'
                            ? 'تم الإنهاء: ${_formatVisitDate(visit.completedAt)}'
                            : 'Completed: ${_formatVisitDate(visit.completedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF15803d),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (visit.description != null &&
                    visit.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    visit.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
