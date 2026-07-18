import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/core/theme/app_dimensions.dart';
import 'package:bustan_amari/presentation/providers/admin_provider.dart';
import 'package:bustan_amari/presentation/screens/admin/widgets/admin_date_filter_bar.dart';
import 'package:bustan_amari/presentation/widgets/status_chip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bustan_amari/core/utils/date_formatter.dart' as date_fmt;

class AdminVisitsTab extends StatefulWidget {
  const AdminVisitsTab({super.key});

  @override
  State<AdminVisitsTab> createState() => _AdminVisitsTabState();
}

class _AdminVisitsTabState extends State<AdminVisitsTab> {
  final Map<String, Future<List<Map<String, dynamic>>>>
  _visitPhotosFutureCache = {};
  final Map<String, Future<List<Map<String, dynamic>>>>
  _visitCommentsFutureCache = {};
  final Map<String, String> _photoUrlCache = {};
  DateTimeRange? _completedDateRange;

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return date.toString().split(' ').first;
    } catch (_) {
      return dateStr.split('T').first;
    }
  }

  String _formatDateTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$day/$month/$year ${date_fmt.formatTime(date)}';
    } catch (_) {
      return dateStr.replaceFirst('T', ' ');
    }
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  bool _inCompletedDateRange(DateTime date) {
    final range = _completedDateRange;
    if (range == null) return true;

    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );

    return !date.isBefore(start) && !date.isAfter(end);
  }

  bool _matchesCompletionDateFilter(Map<String, dynamic> visit) {
    if (_completedDateRange == null) return true;
    if (visit['status']?.toString() != 'completed') return false;

    final completedAt = _parseDateTime(visit['completed_at']);
    if (completedAt == null) return false;
    return _inCompletedDateRange(completedAt);
  }

  DateTime _visitSortDate(Map<String, dynamic> visit) {
    final rawDate = _completedDateRange != null
        ? visit['completed_at']
        : visit['visit_date'];
    return _parseDateTime(rawDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _visitDisplayTitle(AppLocalizations t, Map<String, dynamic> visit) {
    final title = visit['title']?.toString().trim();
    final notes = visit['notes']?.toString().trim();

    if (title != null && title.isNotEmpty) return title;
    if (notes != null && notes.isNotEmpty) return notes;
    return t.locale.languageCode == 'ar' ? 'زيارة' : 'Visit';
  }

  String _visitStatusLabel(AppLocalizations t, String status) {
    return switch (status) {
      'in_progress' => t.locale.languageCode == 'ar' ? 'جارية' : 'In Progress',
      'completed' => t.locale.languageCode == 'ar' ? 'مكتملة' : 'Completed',
      'cancelled' => t.locale.languageCode == 'ar' ? 'ملغاة' : 'Cancelled',
      _ => t.locale.languageCode == 'ar' ? 'مجدولة' : 'Planned',
    };
  }

  void _openVisitDetails(
    BuildContext context,
    AppLocalizations t,
    AdminProvider provider,
    Map<String, dynamic> visit,
  ) async {
    final isCompleted = visit['status']?.toString() == 'completed';
    final visitId = visit['id']?.toString() ?? '';
    final visitPhotosFuture = _getVisitPhotosFuture(visitId);
    final visitCommentsFuture = _getVisitCommentsFuture(visitId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.sm,
              bottom:
                  MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.neutral300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _visitDisplayTitle(t, visit),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textLabel,
                        ),
                        tooltip: t.tr('close'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Status and Date Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusChip.visitStatus(
                        visit['status']?.toString() ?? 'planned',
                        _visitStatusLabel(
                          t,
                          visit['status']?.toString() ?? 'planned',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neutral100,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.neutral200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event_rounded,
                              size: 14,
                              color: AppColors.textLabel,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(
                                visit['visit_date']?.toString() ?? '',
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textLabel,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Contract Info
                  _InfoRow(
                    label: t.locale.languageCode == 'ar'
                        ? 'رقم العقد'
                        : 'Contract Code',
                    value:
                        '#${provider.contractCodeById(visit['contract_id']?.toString() ?? '')}',
                  ),
                  _InfoRow(
                    label: t.locale.languageCode == 'ar'
                        ? 'اسم العميل'
                        : 'Client',
                    value:
                        provider
                            .contractById(
                              visit['contract_id']?.toString() ?? '',
                            )?['client_name']
                            ?.toString() ??
                        '—',
                  ),
                  if (isCompleted &&
                      visit['completed_at']?.toString().trim().isNotEmpty ==
                          true) ...[
                    _InfoRow(
                      label: t.locale.languageCode == 'ar'
                          ? 'تاريخ اكتمال الزيارة'
                          : 'Completed At',
                      value: _formatDateTime(
                        visit['completed_at']?.toString() ?? '',
                      ),
                    ),
                  ],
                  // GPS Location for completed visits
                  if (isCompleted &&
                      visit['gps_lat'] != null &&
                      visit['gps_lng'] != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final lat = visit['gps_lat'] as double?;
                        final lng = visit['gps_lng'] as double?;
                        if (lat == null || lng == null) return;

                        final geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
                        final webUrl = Uri.parse(
                          'https://maps.google.com/?q=$lat,$lng',
                        );

                        final openedGeo = await launchUrl(
                          geoUrl,
                          mode: LaunchMode.externalApplication,
                        );
                        if (openedGeo) return;

                        final openedWeb = await launchUrl(
                          webUrl,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!openedWeb && sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text(t.tr('openMapFailed'))),
                          );
                        }
                      },
                      icon: const Icon(Icons.location_on_outlined),
                      label: Text(
                        t.locale.languageCode == 'ar'
                            ? 'فتح الموقع'
                            : 'Open Location',
                      ),
                    ),
                  ],
                  // Report/Summary for completed visits
                  if (isCompleted &&
                      visit['summary']?.toString().trim().isNotEmpty ==
                          true) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      t.locale.languageCode == 'ar' ? 'التقرير' : 'Report',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      visit['summary']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  // Notes
                  if (visit['notes']?.toString().trim().isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      t.locale.languageCode == 'ar' ? 'الملاحظات' : 'Notes',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      visit['notes']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: visitCommentsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final comments =
                          snapshot.data ?? const <Map<String, dynamic>>[];
                      if (comments.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            t.tr('clientComments'),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          ...comments.map(
                            (comment) => Container(
                              width: double.infinity,
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
                                          comment['author_name']
                                                      ?.toString()
                                                      .trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? comment['author_name']
                                                    .toString()
                                              : t.tr('client'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      Text(
                                        _formatDateTime(
                                          comment['created_at']?.toString() ??
                                              '',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textLabel,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    comment['comment']?.toString() ?? '',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // Images for completed visits
                  if (isCompleted) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      t.locale.languageCode == 'ar' ? 'الصور' : 'Images',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: visitPhotosFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary700,
                            ),
                          );
                        }

                        final photos =
                            snapshot.data ?? const <Map<String, dynamic>>[];
                        if (photos.isEmpty) {
                          return Text(
                            t.locale.languageCode == 'ar'
                                ? 'لا توجد صور'
                                : 'No images',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textLabel),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: photos.length,
                          itemBuilder: (context, index) {
                            final photo = photos[index];
                            return GestureDetector(
                              onTap: () => _openImagePreview(
                                context,
                                photo['photoUrl']?.toString() ?? '',
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    Image.network(
                                      photo['photoUrl']?.toString() ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: AppColors.neutral200,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: AppColors.textLabel,
                                        ),
                                      ),
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          color: AppColors.neutral100,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    Positioned(
                                      left: 8,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.55,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          t.locale.languageCode == 'ar'
                                              ? 'اضغط لعرض'
                                              : 'Tap to preview',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openImagePreview(BuildContext context, String imageUrl) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getVisitPhotosFuture(String visitId) {
    if (visitId.isEmpty) return Future.value(const <Map<String, dynamic>>[]);
    return _visitPhotosFutureCache.putIfAbsent(
      visitId,
      () => _fetchVisitPhotos(visitId),
    );
  }

  Future<List<Map<String, dynamic>>> _getVisitCommentsFuture(String visitId) {
    if (visitId.isEmpty) return Future.value(const <Map<String, dynamic>>[]);
    return _visitCommentsFutureCache.putIfAbsent(
      visitId,
      () => _fetchVisitComments(visitId),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchVisitComments(String visitId) async {
    if (visitId.isEmpty) return [];
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('client_comments')
          .select('id, visit_id, comment, created_at, author_name')
          .eq('visit_id', visitId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVisitPhotos(String visitId) async {
    if (visitId.isEmpty) return [];
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('visit_photos')
          .select('id, photo_path, created_at')
          .eq('visit_id', visitId)
          .order('created_at', ascending: true);

      return await Future.wait<Map<String, dynamic>>(
        (data as List).map((row) async {
          final raw = row as Map<String, dynamic>;
          final photoPath = raw['photo_path']?.toString() ?? '';
          final photoUrl = await _resolvePhotoUrl(photoPath);
          return {
            'id': raw['id'],
            'photoPath': photoPath,
            'photoUrl': photoUrl,
            'createdAt': raw['created_at'],
          };
        }),
      );
    } catch (e) {
      return [];
    }
  }

  Future<String> _resolvePhotoUrl(String photoPath) async {
    if (photoPath.isEmpty) return '';
    if (photoPath.startsWith('http')) return photoPath;

    final cached = _photoUrlCache[photoPath];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.storage
          .from('task-photos')
          .createSignedUrl(photoPath, 60 * 60 * 24);
      _photoUrlCache[photoPath] = response;
      return response;
    } catch (_) {
      try {
        final supabase = Supabase.instance.client;
        final publicUrl = supabase.storage
            .from('task-photos')
            .getPublicUrl(photoPath);
        _photoUrlCache[photoPath] = publicUrl;
        return publicUrl;
      } catch (_) {
        return '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final allVisits = List<Map<String, dynamic>>.from(provider.allVisits);
        final allContracts = List<Map<String, dynamic>>.from(
          provider.allContracts,
        );

        if (allContracts.isEmpty && allVisits.isEmpty) {
          return Center(child: Text(t.tr('noVisits')));
        }

        // Build groups for all contracts, then append visits for unknown contracts.
        final groupedVisits = <String, List<Map<String, dynamic>>>{};
        for (final contract in allContracts) {
          final contractId = contract['id']?.toString();
          if (contractId != null && contractId.isNotEmpty) {
            groupedVisits[contractId] = <Map<String, dynamic>>[];
          }
        }

        for (final visit in allVisits) {
          final contractId = visit['contract_id']?.toString() ?? 'unknown';
          groupedVisits.putIfAbsent(contractId, () => []).add(visit);
        }

        final visibleGroups = groupedVisits.entries
            .map(
              (entry) => MapEntry(
                entry.key,
                entry.value.where(_matchesCompletionDateFilter).toList(),
              ),
            )
            .where((entry) => entry.value.isNotEmpty)
            .toList();

        return RefreshIndicator(
          onRefresh: () async {
            _visitPhotosFutureCache.clear();
            _photoUrlCache.clear();
            await provider.loadDashboard();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                t.locale.languageCode == 'ar'
                    ? 'فلتر بتاريخ اكتمال الزيارة'
                    : 'Filter by visit completion date',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              AdminDateFilterBar(
                range: _completedDateRange,
                onReset: () => setState(() => _completedDateRange = null),
                onChange: (range) {
                  setState(() => _completedDateRange = range);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              if (visibleGroups.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: Center(
                    child: Text(
                      t.locale.languageCode == 'ar'
                          ? 'لا توجد زيارات مكتملة ضمن هذا التاريخ'
                          : 'No completed visits in this date range',
                    ),
                  ),
                )
              else
                ...visibleGroups.expand((entry) {
                  final contractId = entry.key;
                  final visits = List<Map<String, dynamic>>.from(entry.value)
                    ..sort((a, b) {
                      return _visitSortDate(b).compareTo(_visitSortDate(a));
                    });
                  final contract = provider.contractById(contractId);

                  final groupTitle =
                      contract?['code']?.toString() ??
                      (contractId == 'unknown'
                          ? (t.locale.languageCode == 'ar'
                                ? 'عقد غير معروف'
                                : 'Unknown Contract')
                          : contractId);
                  final groupDescription =
                      contract?['client_name']?.toString() ?? '';

                  final completedCount = visits
                      .where((v) => v['status']?.toString() == 'completed')
                      .length;

                  return [
                    ExpansionTile(
                      backgroundColor: AppColors.neutral50.withValues(
                        alpha: 0.5,
                      ),
                      collapsedBackgroundColor: AppColors.neutral50.withValues(
                        alpha: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (groupDescription.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              groupDescription,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textLabel,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            t.locale.languageCode == 'ar'
                                ? 'الزيارات المكتملة: $completedCount من ${visits.length}'
                                : 'Completed visits: $completedCount of ${visits.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textLabel,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      children: visits.isEmpty
                          ? [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md,
                                  0,
                                  AppSpacing.md,
                                  AppSpacing.sm,
                                ),
                                child: Text(
                                  t.locale.languageCode == 'ar'
                                      ? 'لا توجد زيارات لهذا العقد'
                                      : 'No visits for this contract',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textLabel,
                                  ),
                                ),
                              ),
                            ]
                          : visits
                                .map(
                                  (visit) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: _AdminVisitCard(
                                      visit: visit,
                                      theme: theme,
                                      t: t,
                                      onTap: () => _openVisitDetails(
                                        context,
                                        t,
                                        provider,
                                        visit,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ];
                }),
            ],
          ),
        );
      },
    );
  }
}

class _AdminVisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final ThemeData theme;
  final AppLocalizations t;
  final VoidCallback onTap;

  const _AdminVisitCard({
    required this.visit,
    required this.theme,
    required this.t,
    required this.onTap,
  });

  String _formatDate(String dateStr) {
    try {
      return dateStr.split('T').first;
    } catch (_) {
      return dateStr;
    }
  }

  String _visitDisplayTitle(Map<String, dynamic> visit) {
    final title = visit['title']?.toString().trim();
    final notes = visit['notes']?.toString().trim();

    if (title != null && title.isNotEmpty) return title;
    if (notes != null && notes.isNotEmpty) return notes;
    return t.locale.languageCode == 'ar' ? 'زيارة' : 'Visit';
  }

  String _getStatusLabel(String status) {
    return switch (status) {
      'in_progress' => t.locale.languageCode == 'ar' ? 'جارية' : 'In Progress',
      'completed' => t.locale.languageCode == 'ar' ? 'مكتملة' : 'Completed',
      'cancelled' => t.locale.languageCode == 'ar' ? 'ملغاة' : 'Cancelled',
      _ => t.locale.languageCode == 'ar' ? 'مجدولة' : 'Planned',
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = visit['status']?.toString() ?? 'planned';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _visitDisplayTitle(visit),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusChip.visitStatus(status, _getStatusLabel(status)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: AppColors.textLabel,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatDate(visit['visit_date']?.toString() ?? ''),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textLabel,
                        ),
                      ),
                    ),
                  ],
                ),
                if (visit['notes']?.toString().trim().isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    visit['notes']!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textLabel,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
