import 'package:flutter/material.dart';
import 'package:ensdim_landscape/core/notifications/notification_service.dart';
import 'package:ensdim_landscape/core/services/onboarding_tour_service.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/core/theme/app_dimensions.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/domain/entities/app_user.dart';
import 'package:ensdim_landscape/domain/entities/contract.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';
import 'package:ensdim_landscape/presentation/providers/client_provider.dart';
import 'package:ensdim_landscape/presentation/providers/locale_provider.dart';
import 'package:ensdim_landscape/presentation/screens/client/client_contract_details_screen.dart';
import 'package:ensdim_landscape/presentation/screens/client_home_tour_steps.dart';
import 'package:ensdim_landscape/presentation/widgets/custom_app_bar.dart';
import 'package:ensdim_landscape/presentation/widgets/error_view.dart';
import 'package:ensdim_landscape/presentation/widgets/stat_card.dart';
import 'package:provider/provider.dart';

// Index of the "Payments" tab inside ClientContractDetailsScreen's TabBar.
const _kPaymentsTabIndex = 2;

class ClientHomeScreen extends StatefulWidget {
  final AppUser user;

  const ClientHomeScreen({super.key, required this.user});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Onboarding tour target keys — must stay stable across rebuilds.
  final _tourSummaryKey = GlobalKey();
  final _tourQuickAccessKey = GlobalKey();
  final _tourContractsKey = GlobalKey();
  final _tourNavKey = GlobalKey();
  final _tourHelpKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ClientProvider>().loadDashboard();
      _checkPendingNavigation();
      // Wait one more frame so the dashboard content (not its loading
      // spinner) is what's actually mounted when we look up tour keys.
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
    });
  }

  Future<void> _maybeShowTour({bool force = false}) async {
    if (!mounted) return;
    final provider = context.read<ClientProvider>();
    if (provider.status == ClientDataStatus.error) return;

    final steps = buildClientHomeTourSteps(
      context,
      summaryKey: _tourSummaryKey,
      quickAccessKey: _tourQuickAccessKey,
      contractsKey: _tourContractsKey,
      navKey: _tourNavKey,
      helpKey: _tourHelpKey,
    );

    if (force) {
      OnboardingTourService.forceShow(context, steps);
    } else {
      await OnboardingTourService.showIfUnseen(
        context,
        userId: widget.user.id,
        screenId: 'client_home',
        steps: steps,
      );
    }
  }

  void _onHelpPressed() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeShowTour(force: true),
      );
    } else {
      _maybeShowTour(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check pending navigation when app returns from background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingNavigation();
    }
  }

  /// Navigate based on FCM notification tap data — payment reminders open
  /// the relevant contract's Payments tab directly.
  Future<void> _checkPendingNavigation() async {
    final nav = NotificationService.instance.pendingNav;
    if (nav == null || !mounted) return;
    NotificationService.instance.clearPendingNav();

    final type = nav['type'];
    const paymentTypes = {
      'payment_request',
      'payment_due_today',
      'payment_due_1',
      'payment_due_3',
      'payment_late',
      'payment_confirmed',
    };
    if (type == null || !paymentTypes.contains(type)) return;

    final contractId = nav['contractId'];
    if (contractId == null) return;

    final provider = context.read<ClientProvider>();
    Contract? findContract() {
      for (final c in provider.contracts) {
        if (c.id == contractId) return c;
      }
      return null;
    }

    Contract? contract = findContract();
    if (contract == null) {
      await provider.loadDashboard();
      if (!mounted) return;
      contract = findContract();
    }
    if (contract == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: ClientContractDetailsScreen(
            contract: contract!,
            initialTabIndex: _kPaymentsTabIndex,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final screens = [
      _ClientDashboardTab(
        user: widget.user,
        summaryKey: _tourSummaryKey,
        quickAccessKey: _tourQuickAccessKey,
        contractsKey: _tourContractsKey,
      ),
      _ClientContractsTab(user: widget.user),
      const _ClientAccountTab(),
    ];

    return Scaffold(
      appBar: CustomAppBar(
        title: _currentIndex == 0
            ? t.tr('clientOverview')
            : _currentIndex == 1
            ? t.tr('myContracts')
            : t.tr('profile'),
        showBackButton: false,
        leadingActions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: t.tr('switchLanguage'),
            onPressed: () => context.read<LocaleProvider>().toggleLocale(),
          ),
        ],
        actions: [
          IconButton(
            key: _tourHelpKey,
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: t.tr('tourReplay'),
            onPressed: _onHelpPressed,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: t.tr('logout'),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        key: _tourNavKey,
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
            label: t.tr('clientOverview'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.description_outlined),
            selectedIcon: const Icon(Icons.description),
            label: t.tr('myContracts'),
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

class _ClientDashboardTab extends StatelessWidget {
  final AppUser user;
  final GlobalKey summaryKey;
  final GlobalKey quickAccessKey;
  final GlobalKey contractsKey;

  const _ClientDashboardTab({
    required this.user,
    required this.summaryKey,
    required this.quickAccessKey,
    required this.contractsKey,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Consumer<ClientProvider>(
      builder: (context, provider, _) {
        if (provider.status == ClientDataStatus.loading &&
            provider.contracts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.status == ClientDataStatus.error &&
            provider.contracts.isEmpty) {
          return ErrorView(
            message: t.tr('errorLoadingData'),
            onRetry: () => provider.loadDashboard(),
          );
        }

        final totalValue = provider.totalContractsValue;
        final totalPaid = provider.totalPaid;
        final remaining = (totalValue - totalPaid).clamp(0, double.infinity);
        final paidRatio = totalValue > 0 ? (totalPaid / totalValue) : 0.0;

        return RefreshIndicator(
          onRefresh: () => provider.loadDashboard(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Welcome Card - simplified design
              Card(
                key: summaryKey,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.primary100,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              Icons.person,
                              color: AppColors.primary700,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.tr('welcome'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textLabel,
                                  ),
                                ),
                                Text(
                                  user.fullName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t.tr('financialSummary'),
                            style: theme.textTheme.labelLarge,
                          ),
                          Text(
                            '${totalPaid.toStringAsFixed(0)} / ${totalValue.toStringAsFixed(0)} ${t.tr('currencyKwd')}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: paidRatio.clamp(0.0, 1.0),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(10),
                        backgroundColor: AppColors.neutral200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${t.tr('remainingAmount')}: ${remaining.toStringAsFixed(0)} ${t.tr('currencyKwd')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t.tr('quickAccess'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                key: quickAccessKey,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.2,
                children: [
                  StatCard(
                    title: t.tr('totalContracts'),
                    value: '${provider.contracts.length}',
                    icon: Icons.description_outlined,
                    color: AppColors.primary700,
                  ),
                  StatCard(
                    title: t.tr('remainingAmount'),
                    value:
                        '${remaining.toStringAsFixed(0)} ${t.tr('currencyKwd')}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.accent500,
                  ),
                  StatCard(
                    title: t.tr('totalPaid'),
                    value:
                        '${totalPaid.toStringAsFixed(0)} ${t.tr('currencyKwd')}',
                    icon: Icons.payments_outlined,
                    color: AppColors.primary600,
                  ),
                  StatCard(
                    title: t.tr('visits'),
                    value:
                        '${provider.completedVisitsCount}/${provider.totalVisitsCount}',
                    icon: Icons.check_circle_outline,
                    color: AppColors.primary700,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Column(
                key: contractsKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.tr('myContracts'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (provider.contracts.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(t.tr('noContracts')),
                      ),
                    )
                  else
                    ...provider.contracts
                        .take(3)
                        .map(
                          (contract) =>
                              _ClientContractTile(contract: contract),
                        ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClientContractsTab extends StatefulWidget {
  final AppUser user;

  const _ClientContractsTab({required this.user});

  @override
  State<_ClientContractsTab> createState() => _ClientContractsTabState();
}

class _ClientContractsTabState extends State<_ClientContractsTab> {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Consumer<ClientProvider>(
      builder: (context, provider, _) {
        if (provider.status == ClientDataStatus.loading &&
            provider.contracts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.contracts.isEmpty) {
          return Center(child: Text(t.tr('noContracts')));
        }

        final activeCount = provider.contracts
            .where((contract) => contract.status == 'active')
            .length;
        final totalValue = provider.contracts.fold<double>(
          0,
          (sum, contract) => sum + contract.totalValue,
        );

        return RefreshIndicator(
          onRefresh: () => provider.loadDashboard(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Card - simplified design
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.tr('myContracts'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryPill(
                              icon: Icons.description_outlined,
                              label: t.tr('totalContracts'),
                              value: '${provider.contracts.length}',
                              color: AppColors.primary700,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _SummaryPill(
                              icon: Icons.verified_rounded,
                              label: t.tr('activeContracts'),
                              value: '$activeCount',
                              color: AppColors.accent500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t.tr('contractValue'),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${totalValue.toStringAsFixed(0)} ${t.tr('currencyKwd')}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (provider.contracts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(t.tr('noContracts')),
                  ),
                )
              else
                ...List.generate(provider.contracts.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == provider.contracts.length - 1 ? 0 : 8,
                    ),
                    child: _ClientContractTile(
                      contract: provider.contracts[index],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _ClientAccountTab extends StatelessWidget {
  const _ClientAccountTab();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) {
          return Center(child: Text(t.tr('noData')));
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Profile Card - simplified design
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primary100,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        _avatarLetters(user.fullName),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.primary700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user.email.trim().isEmpty ? '-' : user.email.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textLabel,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((user.phone ?? '').isNotEmpty)
                            Text(
                              user.phone!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textLabel,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ProfileInfoCard(
              title: t.tr('accountDetails'),
              rows: [
                _ProfileRowData(label: t.tr('fullName'), value: user.fullName),
                _ProfileRowData(
                  label: t.tr('email'),
                  value: user.email.trim().isEmpty ? '-' : user.email.trim(),
                ),
                _ProfileRowData(
                  label: t.tr('phoneNumber'),
                  value: (user.phone ?? '').isEmpty ? '-' : user.phone!,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.edit_rounded,
              title: t.tr('editProfile'),
              subtitle: t.tr('editProfileHint'),
              onTap: () => _showEditProfileSheet(context, user),
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.lock_reset_rounded,
              title: t.tr('changePassword'),
              subtitle: t.tr('changePasswordHint'),
              onTap: () => _showChangePasswordSheet(context),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  static Future<void> _showEditProfileSheet(
    BuildContext context,
    AppUser user,
  ) async {
    final t = AppLocalizations.of(context);
    final nameController = TextEditingController(text: user.fullName);
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tr('editProfile'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: t.tr('fullName'),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: AppColors.textLabel,
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return t.tr('fullNameRequired');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReadOnlyProfileField(
                      label: t.tr('email'),
                      value: user.email.trim().isEmpty
                          ? '-'
                          : user.email.trim(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReadOnlyProfileField(
                      label: t.tr('phoneNumber'),
                      value: (user.phone ?? '').trim().isEmpty
                          ? '-'
                          : user.phone!,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setState(() => saving = true);
                                final success = await context
                                    .read<AuthProvider>()
                                    .updateProfile(
                                      fullName: nameController.text.trim(),
                                    );
                                if (!context.mounted) {
                                  return;
                                }
                                setState(() => saving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? t.tr('profileUpdated')
                                          : t.tr('profileUpdateFailed'),
                                    ),
                                  ),
                                );
                                if (success && context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(t.tr('saveChanges')),
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

  static Future<void> _showChangePasswordSheet(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        var saving = false;
        var obscureOne = true;
        var obscureTwo = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tr('changePassword'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscureOne,
                      decoration: InputDecoration(
                        labelText: t.tr('newPassword'),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.textLabel,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => obscureOne = !obscureOne),
                          icon: Icon(
                            obscureOne
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppColors.textLabel,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.length < 6) return t.tr('passwordTooShort');
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: confirmController,
                      obscureText: obscureTwo,
                      decoration: InputDecoration(
                        labelText: t.tr('confirmPassword'),
                        prefixIcon: const Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.textLabel,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => obscureTwo = !obscureTwo),
                          icon: Icon(
                            obscureTwo
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppColors.textLabel,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim() !=
                            passwordController.text.trim()) {
                          return t.tr('passwordsDoNotMatch');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setState(() => saving = true);
                                final success = await context
                                    .read<AuthProvider>()
                                    .changePassword(
                                      passwordController.text.trim(),
                                    );
                                if (!context.mounted) {
                                  return;
                                }
                                setState(() => saving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? t.tr('passwordUpdated')
                                          : t.tr('passwordUpdateFailed'),
                                    ),
                                  ),
                                );
                                if (success && context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.lock_reset_rounded),
                        label: Text(t.tr('updatePassword')),
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

  static String _avatarLetters(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return 'U';
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}

class _ReadOnlyProfileField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.primary700,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$value  $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientContractTile extends StatelessWidget {
  final Contract contract;

  const _ClientContractTile({required this.contract});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final statusColor = _contractStatusColor(contract.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.neutral200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<ClientProvider>(),
                child: ClientContractDetailsScreen(contract: contract),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary100,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: AppColors.primary700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      contract.code,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _contractStatusLabel(t, contract.status),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                contract.fullAddress.isNotEmpty
                    ? contract.fullAddress
                    : (contract.addressDetails ?? t.tr('address')),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textLabel),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${contract.totalValue.toStringAsFixed(0)} ${t.tr('currencyKwd')}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _contractStatusColor(String status) {
    return switch (status) {
      'active' => AppColors.primary700,
      'pending' => AppColors.accent500,
      'completed' => AppColors.info,
      'terminated' => AppColors.error,
      'expired' => AppColors.textSecondary,
      _ => AppColors.textSecondary,
    };
  }

  String _contractStatusLabel(AppLocalizations t, String status) {
    return switch (status) {
      'active' => t.tr('statusActive'),
      'pending' => t.tr('statusPending'),
      'completed' => t.tr('completedStatus'),
      'terminated' => t.tr('statusTerminated'),
      'expired' => t.tr('statusExpired'),
      _ => status,
    };
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final String title;
  final List<_ProfileRowData> rows;

  const _ProfileInfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLabel,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRowData {
  final String label;
  final String value;

  const _ProfileRowData({required this.label, required this.value});
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.neutral200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary100,
          child: Icon(icon, color: AppColors.primary700),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textLabel,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        onTap: onTap,
      ),
    );
  }
}
