import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/domain/entities/app_user.dart';
import 'package:ensdim_landscape/presentation/providers/admin_provider.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';
import 'package:ensdim_landscape/presentation/providers/locale_provider.dart';
import 'package:ensdim_landscape/presentation/screens/admin/tabs/admin_contracts_tab.dart';
import 'package:ensdim_landscape/presentation/screens/admin/tabs/admin_finance_tab.dart';
import 'package:ensdim_landscape/presentation/screens/admin/tabs/admin_overview_tab.dart';
import 'package:ensdim_landscape/presentation/screens/admin/tabs/admin_transfers_tab.dart';
import 'package:ensdim_landscape/presentation/screens/admin/widgets/admin_theme.dart';
import 'package:ensdim_landscape/presentation/screens/admin/tabs/admin_visits_tab.dart';
import 'package:ensdim_landscape/presentation/widgets/custom_app_bar.dart';
import 'package:ensdim_landscape/presentation/widgets/error_view.dart';

class AdminHomeScreen extends StatelessWidget {
  final AppUser user;

  const AdminHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminProvider(Supabase.instance.client)..loadDashboard(),
      child: _AdminHomeView(user: user),
    );
  }
}

class _AdminHomeView extends StatefulWidget {
  final AppUser user;

  const _AdminHomeView({required this.user});

  @override
  State<_AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<_AdminHomeView> {
  int _currentIndex = 0;
  static const bool _essentialOnly = true;

  String _txt(AppLocalizations t, String ar, String en) {
    return t.locale.languageCode == 'ar' ? ar : en;
  }

  String _fmtNum(num n) => n.toStringAsFixed(3);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final user = widget.user;

    final navItems = _essentialOnly
        ? [
            _AdminNavItem(
              title: _txt(t, 'لوحة الإدارة', 'Admin Dashboard'),
              tab: const AdminOverviewTab(),
              destination: NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard_rounded),
                label: _txt(t, 'عام', 'Overview'),
              ),
            ),
            _AdminNavItem(
              title: _txt(t, 'الزيارات', 'Visits'),
              tab: const AdminVisitsTab(),
              destination: NavigationDestination(
                icon: const Icon(Icons.event_note_outlined),
                selectedIcon: const Icon(Icons.event_note_rounded),
                label: _txt(t, 'زيارات', 'Visits'),
              ),
            ),
            _AdminNavItem(
              title: _txt(t, 'العقود', 'Contracts'),
              tab: const AdminContractsTab(),
              destination: NavigationDestination(
                icon: const Icon(Icons.description_outlined),
                selectedIcon: const Icon(Icons.description_rounded),
                label: _txt(t, 'عقود', 'Contracts'),
              ),
            ),
          ]
        : [
            _AdminNavItem(
              title: _txt(t, 'لوحة الإدارة', 'Admin Dashboard'),
              tab: const AdminOverviewTab(),
              destination: NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard_rounded),
                label: _txt(t, 'عام', 'Overview'),
              ),
            ),
            _AdminNavItem(
              title: _txt(t, 'الزيارات', 'Visits'),
              tab: const AdminVisitsTab(),
              destination: NavigationDestination(
                icon: const Icon(Icons.event_note_outlined),
                selectedIcon: const Icon(Icons.event_note_rounded),
                label: _txt(t, 'زيارات', 'Visits'),
              ),
            ),
            _AdminNavItem(
              title: _txt(t, 'التحويلات', 'Transfers'),
              tab: const AdminTransfersTab(),
              destination: NavigationDestination(
                icon: const Icon(Icons.swap_horiz_outlined),
                selectedIcon: const Icon(Icons.swap_horiz_rounded),
                label: _txt(t, 'تحويلات', 'Transfers'),
              ),
            ),
            _AdminNavItem(
              title: _txt(t, 'المالية', 'Finance'),
              tab: const AdminFinanceTab(),
              destination: NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
                label: _txt(t, 'مالية', 'Finance'),
              ),
            ),
            _AdminNavItem(
              title: _txt(t, 'العقود', 'Contracts'),
              tab: const AdminContractsTab(),
              destination: NavigationDestination(
                icon: const Icon(Icons.description_outlined),
                selectedIcon: const Icon(Icons.description_rounded),
                label: _txt(t, 'عقود', 'Contracts'),
              ),
            ),
          ];

    if (_currentIndex >= navItems.length) {
      _currentIndex = 0;
    }

    final tabs = navItems.map((item) => item.tab).toList(growable: false);

    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        return Theme(
          data: buildAdminTheme(Theme.of(context)),
          child: Scaffold(
            appBar: CustomAppBar(
              title: navItems[_currentIndex].title,
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
                tooltip: _txt(t, 'تغيير اللغة', 'Switch Language'),
                onPressed: () => context.read<LocaleProvider>().toggleLocale(),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                  ),
                  tooltip: _txt(t, 'تسجيل الخروج', 'Logout'),
                  onPressed: () async => context.read<AuthProvider>().logout(),
                ),
              ],
            ),
            body: _buildBody(context, provider, tabs, user, t),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              destinations: navItems.map((item) => item.destination).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AdminProvider provider,
    List<Widget> tabs,
    AppUser user,
    AppLocalizations t,
  ) {
    if (provider.status == AdminDataStatus.loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(_txt(t, 'جاري التحميل...', 'Loading...')),
          ],
        ),
      );
    }

    if (provider.status == AdminDataStatus.error) {
      return ErrorView(
        message:
            provider.errorMessage ?? _txt(t, 'حدث خطأ', 'Something went wrong'),
        onRetry: provider.loadDashboard,
      );
    }

    if (_currentIndex == 0) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _buildWelcomeCard(context, provider, user, t),
          ),
          const Divider(height: 1),
          Expanded(child: tabs[_currentIndex]),
        ],
      );
    }

    return tabs[_currentIndex];
  }

  Widget _buildWelcomeCard(
    BuildContext context,
    AdminProvider provider,
    AppUser user,
    AppLocalizations t,
  ) {
    final theme = Theme.of(context);
    final activeContracts = provider.filteredContracts.where((contract) {
      return contract['status']?.toString() == 'active';
    }).length;
    final revenue = provider.periodRevenue;
    final net = provider.periodNet;
    final netPositive = net >= 0;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _txt(t, 'نظرة عامة', 'Overview'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryPill(
                  context,
                  Icons.assignment_turned_in_outlined,
                  _txt(t, 'نشطة', 'Active'),
                  '$activeContracts',
                ),
                const SizedBox(width: 8),
                _summaryPill(
                  context,
                  Icons.trending_up_rounded,
                  _txt(t, 'إيراد', 'Revenue'),
                  _fmtNum(revenue),
                ),
                const SizedBox(width: 8),
                _summaryPill(
                  context,
                  netPositive
                      ? Icons.account_balance_wallet_rounded
                      : Icons.warning_amber_rounded,
                  _txt(t, 'صافي', 'Net'),
                  _fmtNum(net),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  netPositive ? Icons.trending_up_rounded : Icons.error_outline,
                  size: 16,
                  color: netPositive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    netPositive
                        ? _txt(
                            t,
                            'الوضع المالي الحالي إيجابي، والإيرادات تغطي المصروفات.',
                            'Financial position is positive and revenue covers expenses.',
                          )
                        : _txt(
                            t,
                            'تنبيه: المصروفات أعلى من الإيرادات في الفترة المحددة.',
                            'Alert: expenses are higher than revenue in the selected period.',
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: netPositive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryPill(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$value $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavItem {
  final String title;
  final Widget tab;
  final NavigationDestination destination;

  const _AdminNavItem({
    required this.title,
    required this.tab,
    required this.destination,
  });
}
