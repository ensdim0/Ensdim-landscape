import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';

class AdminDateFilterBar extends StatelessWidget {
  final DateTimeRange? range;
  final VoidCallback onReset;
  final ValueChanged<DateTimeRange> onChange;

  const AdminDateFilterBar({
    super.key,
    required this.range,
    required this.onReset,
    required this.onChange,
  });

  String _txt(AppLocalizations t, String ar, String en) {
    return t.locale.languageCode == 'ar' ? ar : en;
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _sameRange(DateTimeRange? a, DateTimeRange b) {
    if (a == null) return false;
    return _sameDate(a.start, b.start) && _sameDate(a.end, b.end);
  }

  String _getRangeLabel(BuildContext context, DateTimeRange? r) {
    final t = AppLocalizations.of(context);
    if (r == null) return _txt(t, 'الكل', 'All Dates');

    final now = DateTime.now();
    final thisMonth = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final today = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final last7Days = DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    if (_sameRange(r, today)) return _txt(t, 'اليوم', 'Today');
    if (_sameRange(r, last7Days)) return _txt(t, 'آخر 7 أيام', 'Last 7 Days');
    if (_sameRange(r, thisMonth)) return _txt(t, 'هذا الشهر', 'This Month');

    final df = DateFormat('MMM d, yy');
    return '${df.format(r.start)} - ${df.format(r.end)}';
  }

  void _showFilterSheet(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final now = DateTime.now();

    final thisMonth = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final today = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    final last7Days = DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _txt(t, 'تصفية بالتاريخ', 'Filter by Date'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _FilterSheetTile(
                  title: _txt(t, 'الكل', 'All Dates'),
                  icon: Icons.all_inclusive,
                  selected: range == null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onReset();
                  },
                ),
                _FilterSheetTile(
                  title: _txt(t, 'اليوم', 'Today'),
                  icon: Icons.today,
                  selected: _sameRange(range, today),
                  onTap: () {
                    Navigator.pop(ctx);
                    onChange(today);
                  },
                ),
                _FilterSheetTile(
                  title: _txt(t, 'آخر 7 أيام', 'Last 7 Days'),
                  icon: Icons.date_range,
                  selected: _sameRange(range, last7Days),
                  onTap: () {
                    Navigator.pop(ctx);
                    onChange(last7Days);
                  },
                ),
                _FilterSheetTile(
                  title: _txt(t, 'هذا الشهر', 'This Month'),
                  icon: Icons.calendar_month,
                  selected: _sameRange(range, thisMonth),
                  onTap: () {
                    Navigator.pop(ctx);
                    onChange(thisMonth);
                  },
                ),
                _FilterSheetTile(
                  title: _txt(t, 'تاريخ مخصص', 'Custom Range...'),
                  icon: Icons.edit_calendar,
                  selected:
                      range != null &&
                      !_sameRange(range, today) &&
                      !_sameRange(range, last7Days) &&
                      !_sameRange(range, thisMonth),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: range,
                      builder: (context, child) {
                        return Theme(
                          data: theme.copyWith(
                            colorScheme: theme.colorScheme.copyWith(
                              primary: theme.colorScheme.primary,
                              onPrimary: theme.colorScheme.onPrimary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) onChange(picked);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _getRangeLabel(context, range);
    final hasFilter = range != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _txt(
                AppLocalizations.of(context),
                'الفترة الزمنية',
                'Time Period',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          InkWell(
            onTap: () => _showFilterSheet(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasFilter
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFilter
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: hasFilter
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: hasFilter
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheetTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterSheetTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
