import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ensdim_landscape/core/notifications/notification_service.dart';
import 'package:ensdim_landscape/domain/repositories/supervisor_repository.dart';
import 'package:provider/provider.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/domain/entities/app_user.dart';
import 'package:ensdim_landscape/infrastructure/di/service_locator.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';
import 'package:ensdim_landscape/presentation/providers/locale_provider.dart';
import 'package:ensdim_landscape/presentation/providers/supervisor_provider.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/contracts_list_screen.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/notifications_screen.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/profile_screen.dart';
import 'package:ensdim_landscape/domain/entities/contract.dart';
import 'package:ensdim_landscape/domain/entities/visit.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/standalone_task_detail_screen.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/visit_detail_screen.dart';
import 'package:ensdim_landscape/presentation/screens/supervisor/standalone_tasks_list_screen.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/presentation/widgets/custom_app_bar.dart';
import 'package:ensdim_landscape/presentation/widgets/empty_state.dart';
import 'package:ensdim_landscape/presentation/widgets/error_view.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  final AppUser user;

  const SupervisorDashboardScreen({super.key, required this.user});

  @override
  State<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _unreadCount = 0;
  StreamSubscription<void>? _notifSubscription;
  StreamSubscription<void>? _fcmSubscription;

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupervisorProvider>().loadDashboard();
      _loadUnreadCount();
      _checkPendingNavigation();
    });
    _notifSubscription = ServiceLocator.instance.notificationRepository
        .watchNewNotifications()
        .listen((_) => _loadUnreadCount());
    _fcmSubscription = NotificationService.instance.onForegroundMessage
        .listen((_) => _loadUnreadCount());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifSubscription?.cancel();
    _fcmSubscription?.cancel();
    super.dispose();
  }

  // Re-check pending navigation when app returns from background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingNavigation();
    }
  }

  /// Navigate based on FCM notification tap data.
  Future<void> _checkPendingNavigation() async {
    final nav = NotificationService.instance.pendingNav;
    if (nav == null || !mounted) return;
    NotificationService.instance.clearPendingNav();

    final type = nav['type'];
    try {
      if (type == 'standalone_task_assigned') {
        final taskId = nav['taskId'];
        if (taskId == null) return;
        final task = await ServiceLocator.instance.supervisorRepository
            .getStandaloneTask(taskId);
        if (!mounted) return;
        final provider = context.read<SupervisorProvider>();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StandaloneTaskDetailScreen(task: task, provider: provider),
          ),
        );
      } else if (type == 'client_comment' || type == 'supervisor_note') {
        final visitId    = nav['visitId'];
        final contractId = nav['contractId'];
        if (visitId == null || contractId == null) return;
        final Visit visit = await ServiceLocator.instance.supervisorRepository
            .getVisit(visitId);
        final Contract contract = await ServiceLocator.instance.supervisorRepository
            .getContract(contractId);
        if (!mounted) return;
        final provider = context.read<SupervisorProvider>();
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
    } catch (_) {}
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await ServiceLocator.instance.notificationRepository
          .getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    // Capture provider before pushing — it's not accessible in pushed routes.
    final provider = context.read<SupervisorProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          repository: ServiceLocator.instance.notificationRepository,
          supervisorProvider: provider,
        ),
      ),
    );
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    final screens = [
      _DashboardTab(user: widget.user),
      ContractsListScreen(user: widget.user),
      StandaloneTasksListScreen(user: widget.user),
      ProfileScreen(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: _currentIndex == 0
            ? t.tr('dashboard')
            : _currentIndex == 1
            ? t.tr('contracts')
            : _currentIndex == 2
            ? t.tr('tasks')
            : t.tr('profile'),
        showBackButton: false,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.language,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          tooltip: t.tr('switchLanguage'),
          onPressed: () => context.read<LocaleProvider>().toggleLocale(),
        ),
        actions: [
          // Notifications bell with unread badge
          IconButton(
            tooltip: t.tr('notifications'),
            onPressed: _openNotifications,
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(
                _unreadCount > 9 ? '9+' : '$_unreadCount',
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: Colors.red,
              child: Icon(
                Icons.notifications_outlined,
                color: Theme.of(context).colorScheme.onSurface,
                size: 22,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 22,
            ),
            tooltip: t.tr('logout'),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.cardBackground,
        indicatorColor: AppColors.primary100,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.primary700,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: AppColors.textLabel,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: t.tr('dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.description_outlined),
            selectedIcon: const Icon(Icons.description),
            label: t.tr('contracts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.task_outlined),
            selectedIcon: const Icon(Icons.task_alt),
            label: t.tr('tasks'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: t.tr('profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.tr('logout')),
        content: Text(t.tr('logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.tr('exit')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }
}

/// The main dashboard tab with statistics and quick actions.
class _DashboardTab extends StatelessWidget {
  final AppUser user;

  const _DashboardTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 16.0 : 20.0;

    return Consumer<SupervisorProvider>(
      builder: (context, provider, _) {
        if (provider.status == DataStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.status == DataStatus.error) {
          return ErrorView(
            message: t.tr('errorLoadingData'),
            onRetry: () => provider.loadDashboard(),
          );
        }

        final stats = provider.stats;
        if (stats == null) {
          return EmptyState(
            icon: Icons.dashboard_outlined,
            message: t.tr('noData'),
            onRetry: () => provider.loadDashboard(),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadDashboard(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Greeting + Avatar)
                _buildHeader(context, theme, t),
                const SizedBox(height: 20),

                // Assigned Line info
                if (provider.assignedLine != null) ...[
                  _buildLineCard(context, theme, t, provider),
                  const SizedBox(height: 12),
                ],

                // Overview stats
                _buildStatsRow(context, theme, t, stats),
                const SizedBox(height: 12),

                // Standalone tasks completion for today
                _buildStandaloneTasksTodayCard(context, theme, t, stats),
                const SizedBox(height: 20),

                // Quick Actions
                _buildQuickActions(context, theme, t),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppLocalizations t,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_rounded,
            color: AppColors.primary700,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.tr('welcomeSupervisor'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textLabel,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.fullName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations t,
    SupervisorProvider provider,
  ) {
    final line = provider.assignedLine!;
    final carNumber = (line.carNumber ?? '').trim();
    final phoneNumber = (line.phoneNumber ?? '').trim();

    return _FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                size: 18,
                color: AppColors.primary700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.tr('assignedLine'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textLabel,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            line.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (carNumber.isNotEmpty || phoneNumber.isNotEmpty) ...[
            const Divider(height: 24, color: AppColors.neutral200),
            if (carNumber.isNotEmpty)
              _InfoLine(
                icon: Icons.directions_car_filled_rounded,
                label: t.tr('carNumber'),
                value: carNumber,
              ),
            if (carNumber.isNotEmpty && phoneNumber.isNotEmpty)
              const SizedBox(height: 10),
            if (phoneNumber.isNotEmpty)
              _InfoLine(
                icon: Icons.phone_rounded,
                label: t.tr('phoneNumber'),
                value: phoneNumber,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    ThemeData theme,
    AppLocalizations t,
    SupervisorStats stats,
  ) {
    return _FlatCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.description_outlined,
              value: '${stats.activeContracts}',
              label: t.tr('activeContracts'),
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.neutral200),
          Expanded(
            child: _StatTile(
              icon: Icons.check_circle_outline_rounded,
              value: '${stats.visitsCompletedToday}',
              label: t.tr('visitsCompletedToday'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandaloneTasksTodayCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations t,
    SupervisorStats stats,
  ) {
    final hasTasksToday = stats.standaloneTasksTotalToday > 0;
    final rate = (stats.standaloneTaskCompletionRateToday * 100).toInt();

    return _FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.tr('standaloneTasksTodayCompletion'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textLabel,
                ),
              ),
              if (hasTasksToday)
                Text(
                  '$rate%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasTasksToday
                ? '${stats.standaloneTasksCompletedToday} / ${stats.standaloneTasksTotalToday} ${t.tr('standaloneTasksToday')}'
                : t.tr('noTasksToday'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.standaloneTaskCompletionRateToday,
              minHeight: 8,
              backgroundColor: AppColors.neutral200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    ThemeData theme,
    AppLocalizations t,
  ) {
    return _FlatCard(
      padding: EdgeInsets.zero,
      child: _QuickActionTile(
        icon: Icons.description_outlined,
        title: t.tr('myContracts'),
        subtitle: t.tr('viewContracts'),
        onTap: () {
          final state = context
              .findAncestorStateOfType<_SupervisorDashboardScreenState>();
          state?.switchTab(1);
        },
      ),
    );
  }
}

/// A simple flat container with light border, used across the dashboard.
class _FlatCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _FlatCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: child,
    );
  }
}

/// A single statistic value with an icon and label, no extra decoration.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary700),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textLabel,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// A label/value row with a leading icon, used for assigned-line details.
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textLabel),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textLabel,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// A flat, list-tile style row used for quick actions.
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary700, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textLabel,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textPlaceholder,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
