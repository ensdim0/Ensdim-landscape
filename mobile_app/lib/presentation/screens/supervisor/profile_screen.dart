import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/domain/entities/app_user.dart';
import 'package:bustan_amari/presentation/providers/auth_provider.dart';
import 'package:bustan_amari/presentation/providers/locale_provider.dart';
import 'package:bustan_amari/presentation/providers/supervisor_provider.dart';
import 'package:bustan_amari/presentation/widgets/error_view.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<SupervisorProvider>();
    if (provider.assignedLine == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.loadDashboard();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 16.0 : 20.0;

    return Consumer<SupervisorProvider>(
      builder: (context, provider, _) {
        if (provider.status == DataStatus.loading &&
            provider.assignedLine == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.status == DataStatus.error &&
            provider.assignedLine == null) {
          return ErrorView(
            message: t.tr('errorLoadingData'),
            onRetry: provider.loadDashboard,
          );
        }

        final line = provider.assignedLine;

        return RefreshIndicator(
          onRefresh: provider.loadDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHeader(user: widget.user, t: t),
                const SizedBox(height: 16),
                _SectionCard(
                  title: t.tr('supervisorProfile'),
                  child: Column(
                    children: [
                      _ProfileRow(
                        icon: Icons.person_outline,
                        label: t.tr('fullName'),
                        value: widget.user.fullName,
                      ),
                      const Divider(height: 24, color: AppColors.neutral200),
                      _ProfileRow(
                        icon: Icons.email_outlined,
                        label: t.tr('emailLabel'),
                        value: widget.user.email,
                      ),
                      if ((widget.user.phone ?? '').trim().isNotEmpty) ...[
                        const Divider(
                          height: 24,
                          color: AppColors.neutral200,
                        ),
                        _ProfileRow(
                          icon: Icons.phone_outlined,
                          label: t.tr('phoneNumber'),
                          value: widget.user.phone!.trim(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: t.tr('lineInfo'),
                  child: line == null
                      ? _EmptyLineState(message: t.tr('noLineAssigned'))
                      : Column(
                          children: [
                            _ProfileRow(
                              icon: Icons.label_outline,
                              label: t.tr('lineName'),
                              value: line.name,
                            ),
                            const Divider(
                              height: 24,
                              color: AppColors.neutral200,
                            ),
                            _ProfileRow(
                              icon: Icons.category_outlined,
                              label: t.tr('lineType'),
                              value: line.lineType,
                            ),
                            if ((line.phoneNumber ?? '').trim().isNotEmpty) ...[
                              const Divider(
                                height: 24,
                                color: AppColors.neutral200,
                              ),
                              _ProfileRow(
                                icon: Icons.phone_rounded,
                                label: t.tr('phoneNumber'),
                                value: line.phoneNumber!.trim(),
                              ),
                            ],
                            if ((line.carNumber ?? '').trim().isNotEmpty) ...[
                              const Divider(
                                height: 24,
                                color: AppColors.neutral200,
                              ),
                              _ProfileRow(
                                icon: Icons.directions_car_filled_rounded,
                                label: t.tr('carNumber'),
                                value: line.carNumber!.trim(),
                              ),
                            ],
                            const Divider(
                              height: 24,
                              color: AppColors.neutral200,
                            ),
                            _StatusRow(
                              label: t.tr('lineStatus'),
                              isActive: line.isActive,
                              activeText: t.tr('statusActive'),
                              inactiveText: t.tr('statusTerminated'),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: t.tr('settings'),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.language_rounded,
                        title: t.tr('language'),
                        value: t.tr('switchLanguage'),
                        onTap: () =>
                            context.read<LocaleProvider>().toggleLocale(),
                      ),
                      const Divider(height: 1, color: AppColors.neutral200),
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        title: t.tr('logout'),
                        iconColor: AppColors.error,
                        titleColor: AppColors.error,
                        onTap: () => _confirmLogout(context, t),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context, AppLocalizations t) async {
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

class _ProfileHeader extends StatelessWidget {
  final AppUser user;
  final AppLocalizations t;

  const _ProfileHeader({required this.user, required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 30,
            color: AppColors.primary700,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textLabel,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t.tr('supervisor'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A simple flat container with a title and light border.
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _EmptyLineState extends StatelessWidget {
  final String message;

  const _EmptyLineState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: AppColors.textLabel,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isActive;
  final String activeText;
  final String inactiveText;

  const _StatusRow({
    required this.label,
    required this.isActive,
    required this.activeText,
    required this.inactiveText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? AppColors.success : AppColors.error;

    return Row(
      children: [
        Icon(Icons.flag_outlined, size: 18, color: AppColors.textLabel),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textLabel,
            ),
          ),
        ),
        Text(
          isActive ? activeText : inactiveText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textLabel),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textLabel,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// A flat, tappable settings row.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.iconColor,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.primary700),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: titleColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textLabel,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textPlaceholder,
            ),
          ],
        ),
      ),
    );
  }
}
