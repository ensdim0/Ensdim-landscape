// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ensdim_landscape/core/services/onboarding_tour_service.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/core/theme/app_dimensions.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/domain/entities/contract.dart';
import 'package:ensdim_landscape/domain/entities/contract_payment.dart';
import 'package:ensdim_landscape/domain/entities/contract_task.dart';
import 'package:ensdim_landscape/domain/entities/standalone_task.dart';
import 'package:ensdim_landscape/domain/entities/supervisor_note.dart';
import 'package:ensdim_landscape/domain/entities/visit.dart';
import 'package:ensdim_landscape/infrastructure/di/service_locator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ensdim_landscape/presentation/providers/auth_provider.dart';
import 'package:ensdim_landscape/presentation/providers/client_provider.dart';
import 'package:ensdim_landscape/presentation/widgets/custom_app_bar.dart';
import 'package:ensdim_landscape/presentation/widgets/expandable_section.dart';
import 'package:ensdim_landscape/presentation/widgets/status_chip.dart';
import 'package:ensdim_landscape/presentation/screens/client/client_standalone_task_detail_screen.dart';
import 'package:ensdim_landscape/presentation/screens/client/payment_webview_screen.dart';
import 'package:ensdim_landscape/presentation/screens/client/payment_receipt_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ensdim_landscape/core/utils/date_formatter.dart' as date_fmt;

bool _isVideoPath(String path) {
  final normalized = path.split('?').first.toLowerCase();
  return normalized.endsWith('.mp4') ||
      normalized.endsWith('.mov') ||
      normalized.endsWith('.m4v') ||
      normalized.endsWith('.avi') ||
      normalized.endsWith('.webm') ||
      normalized.endsWith('.mkv');
}

class _StandaloneTasksTab extends StatelessWidget {
  final String contractId;
  final String contractCode;
  final List<StandaloneTask> tasks;

  const _StandaloneTasksTab({
    required this.contractId,
    required this.contractCode,
    required this.tasks,
  });

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

  String _fmtDate(String value) {
    final dt = _parse(value);
    if (dt == null) return value.split('T').first.split(' ').first;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  String _fmtTime(String value) {
    final dt = _parse(value);
    if (dt == null) return '';
    final h = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'م' : 'ص';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$min $period';
  }

  bool _hasTime(String value) =>
      value.contains('T') ||
      (value.contains(' ') && RegExp(r'\d{2}:\d{2}').hasMatch(value));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.tr('noTasksYet'), style: theme.textTheme.titleMedium),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          elevation: 0,
          color: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClientStandaloneTaskDetailScreen(
                    task: task,
                    contractCode: contractCode,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textPlaceholder,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (task.description != null && task.description!.isNotEmpty)
                    Text(
                      task.description!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textPlaceholder,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _fmtDate(task.taskDate),
                        style: theme.textTheme.labelSmall,
                      ),
                      if (_hasTime(task.taskDate)) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textPlaceholder,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _fmtTime(task.taskDate),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                      const SizedBox(width: 12),
                      if (task.cost != null) ...[
                        Icon(
                          Icons.attach_money,
                          size: 14,
                          color: AppColors.textPlaceholder,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          task.cost!.toStringAsFixed(2),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ClientContractDetailsScreen extends StatefulWidget {
  final Contract contract;
  final int initialTabIndex;

  const ClientContractDetailsScreen({
    super.key,
    required this.contract,
    this.initialTabIndex = 0,
  });

  @override
  State<ClientContractDetailsScreen> createState() =>
      _ClientContractDetailsScreenState();
}

class _ClientContractDetailsScreenState
    extends State<ClientContractDetailsScreen> {
  final _tourHeaderKey = GlobalKey();
  final _tourTabBarKey = GlobalKey();
  final _tourHelpKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ClientProvider>().selectContract(widget.contract);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
    });
  }

  Future<void> _maybeShowTour({bool force = false}) async {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    final t = AppLocalizations.of(context);

    final steps = [
      TourStep(
        key: _tourHeaderKey,
        title: t.tr('tourContractHeaderTitle'),
        description: t.tr('tourContractHeaderDesc'),
      ),
      TourStep(
        key: _tourTabBarKey,
        title: t.tr('tourContractTabsTitle'),
        description: t.tr('tourContractTabsDesc'),
      ),
      TourStep(
        key: _tourHelpKey,
        title: t.tr('tourHomeHelpTitle'),
        description: t.tr('tourHomeHelpDesc'),
      ),
    ];

    if (force) {
      OnboardingTourService.forceShow(context, steps);
    } else {
      await OnboardingTourService.showIfUnseen(
        context,
        userId: userId,
        screenId: 'client_contract_details',
        steps: steps,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Consumer<ClientProvider>(
      builder: (context, provider, _) {
        final activeContract =
            provider.selectedContract?.id == widget.contract.id
            ? provider.selectedContract!
            : widget.contract;
        final contractId = activeContract.id;
        final payments = provider.paymentsFor(contractId);
        final visits = provider.visitsFor(contractId);

        return DefaultTabController(
          length: 5,
          initialIndex: widget.initialTabIndex,
          child: Scaffold(
            appBar: CustomAppBar(
              title: t.tr('contractDetails'),
              backButtonBackgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  key: _tourHelpKey,
                  icon: const Icon(Icons.help_outline_rounded),
                  tooltip: t.tr('tourReplay'),
                  onPressed: () => _maybeShowTour(force: true),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: t.tr('retry'),
                  onPressed: () =>
                      context.read<ClientProvider>().refreshSelectedContract(),
                ),
              ],
            ),
            body: Column(
              children: [
                KeyedSubtree(
                  key: _tourHeaderKey,
                  child: _ContractHeader(contract: activeContract),
                ),
                const SizedBox(height: 2),
                TabBar(
                  key: _tourTabBarKey,
                  isScrollable: true,
                  tabs: [
                    Tab(text: t.tr('overviewTab')),
                    Tab(text: t.tr('visits')),
                    Tab(text: t.tr('contractPayments')),
                    Tab(text: t.tr('contractTerms')),
                    Tab(text: t.tr('standaloneTasks')),
                  ],
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: TabBarView(
                      children: [
                        _OverviewTab(
                          contract: activeContract,
                          payments: payments,
                          visits: visits,
                        ),
                        _VisitsTab(
                          visits: visits,
                          terms: activeContract.terms,
                          tasks: provider.tasksFor(contractId),
                        ),
                        _PaymentsTab(
                          payments: payments,
                          contractId: contractId,
                          contract: activeContract,
                          visits: visits,
                        ),
                        _TermsTab(terms: activeContract.terms),
                        _StandaloneTasksTab(
                          contractId: contractId,
                          contractCode: activeContract.code,
                          tasks: provider.standaloneTasksFor(contractId),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContractHeader extends StatelessWidget {
  final Contract contract;

  const _ContractHeader({required this.contract});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contract.code,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusChip(
                    label: _statusLabel(t, contract.status),
                    color: _statusColor(contract.status),
                  ),
                ],
              ),
              _SmallInfoChip(
                icon: Icons.payments_outlined,
                text: _formatCurrency(t, contract.totalValue),
              ),
            ],
          ),
          if (contract.startDate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(contract.startDate),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Contract contract;
  final List<ContractPayment> payments;
  final List<Visit> visits;

  const _OverviewTab({
    required this.contract,
    required this.payments,
    required this.visits,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final totalPaid = payments
        .where(
          (p) =>
              p.gatewayStatus == 'paid' ||
              (p.gatewayStatus == null && p.dueDate == null),
        )
        .fold(0.0, (sum, p) => sum + p.amount);
    final remaining = (contract.totalValue - totalPaid)
        .clamp(0, double.infinity)
        .toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.tr('contractSummary'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: t.tr('contractValue'),
                  value: _formatCurrency(t, contract.totalValue),
                ),
                _InfoRow(
                  label: t.tr('totalPaid'),
                  value: _formatCurrency(t, totalPaid),
                ),
                _InfoRow(
                  label: t.tr('remainingAmount'),
                  value: _formatCurrency(t, remaining),
                ),
                _InfoRow(label: t.tr('totalVisits'), value: '${visits.length}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.tr('address'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  contract.fullAddress.isNotEmpty
                      ? contract.fullAddress
                      : (contract.addressDetails ?? t.tr('noData')),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (contract.palmInfo != null && contract.palmInfo!.isPalm) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل النخيل',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PalmInfoCard(palmInfo: contract.palmInfo!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _ContractImageCard(imageUrl: contract.contractImageUrl),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        t.tr('guardInfo'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _showEditGuardInfoSheet(context, contract),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(t.tr('editGuardInfo')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: t.tr('clientName'),
                  value: (contract.contractUserName ?? '').trim().isEmpty
                      ? t.tr('noData')
                      : contract.contractUserName!.trim(),
                ),
                _InfoRow(
                  label: t.tr('clientPhone'),
                  value: (contract.contractUserPhone ?? '').trim().isEmpty
                      ? t.tr('noData')
                      : contract.contractUserPhone!.trim(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showEditGuardInfoSheet(
  BuildContext context,
  Contract contract,
) async {
  final t = AppLocalizations.of(context);
  final guardNameController = TextEditingController(
    text: contract.contractUserName ?? '',
  );
  final guardPhoneController = TextEditingController(
    text: contract.contractUserPhone ?? '',
  );
  final formKey = GlobalKey<FormState>();

  try {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        var saving = false;

        return StatefulBuilder(
          builder: (sheetStateContext, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tr('editGuardInfo'),
                      style: Theme.of(sheetStateContext).textTheme.titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: guardNameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t.tr('clientName'),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: AppColors.textLabel,
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return t.tr('guardNameRequired');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: guardPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: t.tr('clientPhone'),
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.textLabel,
                        ),
                      ),
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
                                if (!sheetStateContext.mounted) return;
                                FocusScope.of(sheetContext).unfocus();
                                // Disable button without setState to avoid widget tree issues
                                saving = true;

                                final success = await context
                                    .read<ClientProvider>()
                                    .updateContractGuardInfo(
                                      contractId: contract.id,
                                      guardName: guardNameController.text
                                          .trim(),
                                      guardPhone: guardPhoneController.text
                                          .trim(),
                                    );

                                if (!sheetStateContext.mounted) {
                                  return;
                                }

                                Navigator.of(sheetContext).pop(success);
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

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.tr('guardInfoUpdatedSuccess'))));
    } else if (result == false && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.tr('guardInfoUpdateFailed'))));
    }
  } finally {
    guardNameController.dispose();
    guardPhoneController.dispose();
  }
}

class _ContractImageCard extends StatelessWidget {
  final String? imageUrl;
  static const MethodChannel _galleryChannel = MethodChannel(
    'ensdim_landscape/gallery',
  );

  const _ContractImageCard({required this.imageUrl});

  Future<void> _openImagePreview(BuildContext context, String url) async {
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
                      url,
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

  Future<void> _downloadImage(BuildContext context, String url) async {
    final t = AppLocalizations.of(context);
    try {
      await _saveImageToDeviceGallery(url);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.tr('downloadImageSuccess'))));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.tr('downloadImageFailed'))));
    }
  }

  Future<void> _saveImageToDeviceGallery(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw const FormatException('Invalid image url');
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Failed to download image');
      }

      final bytes = await response.fold<List<int>>(<int>[], (buffer, data) {
        buffer.addAll(data);
        return buffer;
      });

      final packageInfo = await PackageInfo.fromPlatform();
      final appName = packageInfo.appName.trim().isEmpty
          ? 'Ensdim Landscape System'
          : packageInfo.appName.trim();

      final extension = _inferImageExtension(
        uri,
        response.headers.contentType?.mimeType,
      );
      final fileName =
          'contract_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final savedPath = await _galleryChannel
          .invokeMethod<String>('saveImageToGallery', <String, dynamic>{
            'bytes': Uint8List.fromList(bytes),
            'fileName': fileName,
            'folderName': appName,
          });
      if (savedPath == null || savedPath.isEmpty) {
        throw const FileSystemException('Gallery save failed');
      }
    } finally {
      client.close(force: true);
    }
  }

  String _inferImageExtension(Uri uri, String? mimeType) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.png') || mimeType == 'image/png') return 'png';
    if (path.endsWith('.webp') || mimeType == 'image/webp') return 'webp';
    if (path.endsWith('.gif') || mimeType == 'image/gif') return 'gif';
    if (path.endsWith('.bmp') || mimeType == 'image/bmp') return 'bmp';
    return 'jpg';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final normalizedUrl = (imageUrl ?? '').trim();
    final imageUri = Uri.tryParse(normalizedUrl);
    final hasImage =
        normalizedUrl.isNotEmpty &&
        imageUri != null &&
        (imageUri.scheme == 'http' || imageUri.scheme == 'https');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.tr('contractImage'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (!hasImage)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.tr('noContractImage'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              GestureDetector(
                onTap: () => _openImagePreview(context, normalizedUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Image.network(
                          normalizedUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
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
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            t.tr('tapToPreview'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _openImagePreview(context, normalizedUrl),
                      icon: const Icon(Icons.zoom_in_rounded),
                      label: Text(t.tr('viewImage')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadImage(context, normalizedUrl),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(t.tr('downloadImage')),
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
}

class _PaymentsTab extends StatefulWidget {
  final List<ContractPayment> payments;
  final String contractId;
  final Contract? contract;
  final List<Visit> visits;

  const _PaymentsTab({
    required this.payments,
    required this.contractId,
    this.contract,
    this.visits = const [],
  });

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  List<ContractPayment> _payments = [];
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _payments = widget.payments;
    _subscribeRealtime();
  }

  @override
  void didUpdateWidget(_PaymentsTab old) {
    super.didUpdateWidget(old);
    if (old.payments != widget.payments) {
      setState(() => _payments = widget.payments);
    }
  }

  void _subscribeRealtime() {
    _subscription = Supabase.instance.client
        .channel('payments_${widget.contractId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'contract_payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'contract_id',
            value: widget.contractId,
          ),
          callback: (_) => _reload(),
        )
        .subscribe();
  }

  Future<void> _reload() async {
    try {
      final rows = await Supabase.instance.client
          .from('contract_payments')
          .select()
          .eq('contract_id', widget.contractId)
          .order('payment_date', ascending: false);
      if (!mounted) return;
      setState(() {
        _payments = (rows as List).map((row) {
          final r = row as Map<String, dynamic>;
          return ContractPayment(
            id: r['id'] as String,
            contractId: r['contract_id'] as String,
            amount: (r['amount'] as num?)?.toDouble() ?? 0.0,
            paymentMethod: r['payment_method']?.toString() ?? 'cash',
            paymentDate: r['payment_date']?.toString() ?? '',
            transferImageUrl: r['transfer_image_url']?.toString(),
            notes: r['notes']?.toString(),
            createdAt: r['created_at']?.toString() ?? '',
            dueDate: r['due_date']?.toString(),
            paymentGatewayUrl: r['payment_gateway_url']?.toString(),
            paymentGatewayOrderId: r['payment_gateway_order_id']?.toString(),
            gatewayStatus: r['gateway_status']?.toString(),
            gatewayFeeAmount: (r['gateway_fee_amount'] as num?)?.toDouble(),
            receiptUrl: r['receipt_url']?.toString(),
            gatewayPaymentMethod: r['gateway_payment_method']?.toString(),
            receiptData: r['receipt_data'] is Map
                ? Map<String, dynamic>.from(r['receipt_data'] as Map)
                : null,
          );
        }).toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _openGateway(ContractPayment payment) async {
    if (!mounted) return;

    // Generate a fresh payment URL (non-white-label: UPayments shows all methods)
    String paymentUrl;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final res = await Supabase.instance.client.functions.invoke(
        'create-upayment-charge',
        body: {
          'paymentId': payment.id,
          'paymentType': 'contract',
          'amount': payment.amount,
          'clientUserId': userId,
          'contractId': widget.contractId,
          // no gatewaySrc → non-white-label mode → all methods shown
          // client is already on this screen — skip the "go pay" push
          'silent': true,
        },
      );
      final data = res.data as Map<String, dynamic>?;
      paymentUrl = data?['paymentUrl']?.toString() ?? '';
      if (paymentUrl.isEmpty) throw Exception('no paymentUrl');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل إنشاء رابط الدفع: $e')));
      return;
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(
          paymentUrl: paymentUrl,
          paymentId: payment.id,
          paymentType: 'contract',
          contractId: widget.contractId,
          amount: payment.amount,
        ),
      ),
    );
    if (result == true) await _reload();
  }

  Future<void> _openReceipt(ContractPayment payment) async {
    final c   = widget.contract;
    final snap = payment.receiptData; // frozen snapshot saved at payment time

    // ── client/address fields (never frozen — always from contract) ───────────
    final addr  = c?.fullAddress;
    final name  = (c?.contractUserName?.isNotEmpty == true) ? c!.contractUserName : c?.clientName;
    final phone = (c?.contractUserPhone?.isNotEmpty == true) ? c!.contractUserPhone : c?.clientPhone;

    // ── financial/visit fields: prefer frozen snapshot, fall back to live ─────
    final contractTotalValue = snap != null
        ? (snap['contractTotalValue'] as num?)?.toDouble()
        : c?.totalValue;

    final totalPaidAmount = snap != null
        ? (snap['totalPaidAtTime'] as num?)?.toDouble()
        : _payments
            .where((p) => p.gatewayStatus == 'paid' || (p.gatewayStatus == null && p.dueDate == null))
            .fold<double>(0.0, (sum, p) => sum + p.amount);

    final totalVisits = snap != null
        ? (snap['totalVisitsCount'] as int?)
        : (widget.visits.isNotEmpty ? widget.visits.length : null);

    final completedVisits = snap != null
        ? (snap['completedVisitsCount'] as int?) ?? 0
        : widget.visits.where((v) => v.isCompleted).length;

    final contractType      = snap?['contractType']      as String? ?? c?.contractType;
    final contractStartDate = snap?['contractStartDate'] as String? ?? c?.startDate;
    final contractEndDate   = snap?['contractEndDate']   as String? ?? c?.endDate;

    ContractPalmInfo? palmInfo;
    if (snap != null && snap['palmInfo'] != null) {
      palmInfo = ContractPalmInfo.fromJson(snap['palmInfo']);
    } else {
      palmInfo = c?.palmInfo;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentReceiptScreen(
          paymentId:             payment.id,
          paymentType:           'contract',
          contractId:            widget.contractId,
          amount:                payment.amount,
          receiptUrl:            payment.receiptUrl,
          contractCode:          c?.code,
          clientName:            name,
          clientPhone:           phone,
          address:               (addr != null && addr.isNotEmpty) ? addr : null,
          dueDate:               payment.dueDate,
          paymentDate:           payment.paymentDate,
          createdAt:             payment.createdAt,
          paymentGatewayOrderId: payment.paymentGatewayOrderId,
          gatewayPaymentMethod:  payment.gatewayPaymentMethod,
          contractType:          contractType,
          contractStartDate:     contractStartDate,
          contractEndDate:       contractEndDate,
          contractTotalValue:    contractTotalValue,
          totalPaidAmount:       totalPaidAmount,
          totalVisitsCount:      totalVisits,
          completedVisitsCount:  completedVisits,
          palmInfo:              palmInfo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_payments.isEmpty) {
      return Center(child: Text(t.tr('noPayments')));
    }

    bool isPaid(ContractPayment p) =>
        p.gatewayStatus == 'paid' ||
        (p.gatewayStatus == null && p.dueDate == null);

    final latePayments = _payments.where((p) => p.isLate).toList()
      ..sort((a, b) => (a.dueDate ?? '').compareTo(b.dueDate ?? ''));

    final scheduledPayments =
        _payments.where((p) => !isPaid(p) && !p.isLate).toList()
          ..sort((a, b) => (a.dueDate ?? '').compareTo(b.dueDate ?? ''));

    final paidPayments = _payments.where(isPaid).toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    // أول دفعة "عليها الدور" فعلاً: المتأخرة أولاً وإلا أقرب المجدولة
    final nextActionId = latePayments.isNotEmpty
        ? latePayments.first.id
        : (scheduledPayments.isNotEmpty ? scheduledPayments.first.id : null);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (latePayments.isNotEmpty) ...[
          ExpandableSection(
            title: t.tr('paymentsSectionLate'),
            count: latePayments.length,
            color: Colors.red.shade700,
            children: [
              for (final payment in latePayments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PaymentCard(
                    payment: payment,
                    theme: theme,
                    t: t,
                    highlightNext: payment.id == nextActionId,
                    onPayNow: () => _openGateway(payment),
                    onViewReceipt: () => _openReceipt(payment),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (scheduledPayments.isNotEmpty) ...[
          ExpandableSection(
            title: t.tr('paymentsSectionScheduled'),
            count: scheduledPayments.length,
            color: Colors.blue.shade700,
            children: [
              for (final payment in scheduledPayments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PaymentCard(
                    payment: payment,
                    theme: theme,
                    t: t,
                    highlightNext: payment.id == nextActionId,
                    onPayNow: () => _openGateway(payment),
                    onViewReceipt: () => _openReceipt(payment),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (paidPayments.isNotEmpty)
          ExpandableSection(
            title: t.tr('paymentsSectionPaid'),
            count: paidPayments.length,
            color: Colors.green.shade700,
            initiallyExpanded: false,
            children: [
              for (final payment in paidPayments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PaymentCard(
                    payment: payment,
                    theme: theme,
                    t: t,
                    onPayNow: () => _openGateway(payment),
                    onViewReceipt: () => _openReceipt(payment),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final ContractPayment payment;
  final ThemeData theme;
  final AppLocalizations t;
  final VoidCallback onPayNow;
  final VoidCallback onViewReceipt;
  final bool highlightNext;

  const _PaymentCard({
    required this.payment,
    required this.theme,
    required this.t,
    required this.onPayNow,
    required this.onViewReceipt,
    this.highlightNext = false,
  });

  @override
  Widget build(BuildContext context) {
    final isGatewayPaid = payment.isPaidViaGateway;
    final isGatewayPending = payment.isPendingGateway;
    final isScheduled = payment.isScheduledNotSent;
    final isLate = payment.isLate;

    Widget? statusBadge;
    if (isGatewayPaid) {
      statusBadge = _Badge(
        label: t.tr('paymentStatusPaidElectronically'),
        color: Colors.green.shade700,
        bg: Colors.green.shade50,
      );
    } else if (isLate) {
      statusBadge = _Badge(
        label:
            '${t.tr('paymentStatusLate')}: ${_formatDate(payment.dueDate ?? '')}',
        color: Colors.red.shade700,
        bg: Colors.red.shade50,
      );
    } else if (isGatewayPending) {
      statusBadge = _Badge(
        label: t.tr('paymentStatusAwaiting'),
        color: Colors.orange.shade800,
        bg: Colors.orange.shade50,
      );
    } else if (isScheduled) {
      final due = payment.dueDate ?? '';
      statusBadge = _Badge(
        label: '${t.tr('paymentStatusScheduled')}: ${_formatDate(due)}',
        color: Colors.blue.shade700,
        bg: Colors.blue.shade50,
      );
    } else if (payment.isTransfer) {
      statusBadge = StatusChip(
        label: t.tr('paymentMethodTransfer'),
        color: Colors.blue,
      );
    } else if (payment.isCheque) {
      statusBadge = StatusChip(
        label: t.tr('paymentMethodCheque'),
        color: Colors.purple,
      );
    } else if (payment.isCard) {
      statusBadge = StatusChip(
        label: t.tr('paymentMethodCard'),
        color: Colors.teal,
      );
    } else if (payment.isCash) {
      statusBadge = StatusChip(
        label: t.tr('paymentMethodCash'),
        color: Colors.green,
      );
    } else {
      statusBadge = StatusChip(
        label: t.tr('paymentMethodGateway'),
        color: Colors.green,
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          width: highlightNext ? 1.5 : 1,
          color: highlightNext
              ? theme.colorScheme.primary
              : isLate
              ? Colors.red.shade200
              : isGatewayPending
              ? Colors.orange.shade200
              : isGatewayPaid
              ? Colors.green.shade200
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (highlightNext) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.push_pin_rounded,
                    size: 13,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    t.tr('paymentNextUp'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCurrency(t, payment.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                statusBadge,
              ],
            ),
            const SizedBox(height: 8),
            if (!isScheduled)
              Text(
                '${t.tr('paymentDate')}: ${_formatDate(payment.paymentDate)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (isScheduled && payment.dueDate != null)
              Text(
                '${t.tr('paymentDueDate')}: ${_formatDate(payment.dueDate!)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isLate ? Colors.red.shade700 : Colors.blue.shade700,
                ),
              ),
            if ((payment.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${t.tr('paymentNotes')}: ${payment.notes}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (isGatewayPaid &&
                payment.gatewayFeeAmount != null &&
                payment.gatewayFeeAmount! > 0) ...[
              const SizedBox(height: 6),
              Text(
                'رسوم البوابة: ${payment.gatewayFeeAmount!.toStringAsFixed(3)} د.ك',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            if (isGatewayPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onPayNow,
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: const Text('ادفع الآن'),
                ),
              ),
            ],
            if (isGatewayPaid) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onViewReceipt,
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('عرض الفاتورة'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _Badge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VisitsTab extends StatefulWidget {
  final List<Visit> visits;
  final List<ContractTerm> terms;
  final List<ContractTask> tasks;

  const _VisitsTab({
    required this.visits,
    required this.terms,
    required this.tasks,
  });

  @override
  State<_VisitsTab> createState() => _VisitsTabState();
}

class _VisitsTabState extends State<_VisitsTab> {
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  final ImagePicker _imagePicker = ImagePicker();
  String? _pickedAttachmentPath;

  Future<void> _showCommentErrorDialog(
    BuildContext context,
    AppLocalizations t,
    String message,
  ) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_trSafe(t, 'errorLoadingData', 'حدث خطأ')),
          content: SelectableText(message),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _trSafe(t, 'errorCopiedToClipboard', 'تم نسخ الخطأ'),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(_trSafe(t, 'copyError', 'نسخ الخطأ')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.tr('confirm')),
            ),
          ],
        );
      },
    );
  }

  String _trSafe(AppLocalizations t, String key, String fallback) {
    final value = t.tr(key);
    return value == key ? fallback : value;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  List<ContractTask> _tasksForVisit(String visitId) {
    return widget.tasks.where((task) => task.visitId == visitId).toList();
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

  Future<void> _openMediaPreview(BuildContext context, String mediaUrl) async {
    if (_isVideoPath(mediaUrl)) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(12),
            child: _NetworkVideoPreview(videoUrl: mediaUrl),
          );
        },
      );
      return;
    }

    await _openImagePreview(context, mediaUrl);
  }

  Widget _buildMediaThumbnail({
    required String mediaPath,
    required double size,
    required double radius,
  }) {
    final isVideo = _isVideoPath(mediaPath);
    if (isVideo) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.neutral900,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.videocam_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: size >= 90 ? 28 : 22,
            ),
            Container(
              width: size >= 90 ? 32 : 28,
              height: size >= 90 ? 32 : 28,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: size >= 90 ? 20 : 18,
              ),
            ),
          ],
        ),
      );
    }

    return Image.network(
      mediaPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        color: AppColors.neutral100,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: AppColors.textLabel),
      ),
    );
  }

  Future<void> _openVisitDetails(BuildContext context, Visit visit) async {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isCompleted = visit.status == 'completed';
    _commentController.clear();
    final clientProvider = context.read<ClientProvider>();
    final tasksForVisit = _tasksForVisit(visit.id);
    final taskIds = (tasksForVisit.isNotEmpty ? tasksForVisit : widget.tasks)
        .map((t) => t.id)
        .toList(growable: false);
    final notesFuture = ServiceLocator.instance.supervisorRepository
        .listSupervisorNotes(visit.id)
        .catchError((_) => <SupervisorNote>[]);
    final detailsFuture = Future.wait([
      clientProvider.loadVisitPhotos(visit.id, forceReload: true),
      clientProvider.loadVisitTaskDetails(
        visit.id,
        forceReload: true,
        taskIds: taskIds,
      ),
      clientProvider.loadVisitComments(visit.id, forceReload: true),
      notesFuture,
    ]);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              border: Border.all(color: AppColors.neutral200),
              boxShadow: AppShadows.lg,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.sm,
                bottom:
                    MediaQuery.of(sheetContext).viewInsets.bottom +
                    AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                            style: theme.textTheme.titleMedium?.copyWith(
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusChip.visitStatus(
                          visit.status,
                          _visitStatusLabel(t, visit.status),
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
                              Icon(
                                Icons.event_rounded,
                                size: 14,
                                color: AppColors.textLabel,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatVisitDate(visit.visitDate),
                                style: theme.textTheme.bodySmall?.copyWith(
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
                    FutureBuilder<List<dynamic>>(
                      future: detailsFuture,
                      builder: (context, snapshot) {
                        final directPhotos = clientProvider.visitPhotosFor(
                          visit.id,
                        );
                        final comments = clientProvider.visitCommentsFor(
                          visit.id,
                        );
                        final executions = clientProvider
                            .taskExecutionsForVisit(visit.id);
                        final taskPhotos = clientProvider.taskPhotosForVisit(
                          visit.id,
                        );
                        final sanitizedSummary = _sanitizeVisitSummary(
                          visit.summary,
                        );
                        final supervisorNotes =
                            snapshot.data != null && snapshot.data!.length > 3
                            ? (snapshot.data![3] as List<SupervisorNote>)
                                  .where((n) => n.isVisibleToClients)
                                  .toList(growable: false)
                            : const <SupervisorNote>[];

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

                        final content = <Widget>[];

                        if (isCompleted) {
                          if (visit.completedAt != null) {
                            content.add(
                              _InfoRow(
                                label: t.locale.languageCode == 'ar'
                                    ? 'تاريخ ووقت الإكمال'
                                    : 'Completion Date & Time',
                                value: _formatDateTime(visit.completedAt),
                              ),
                            );
                            content.add(const SizedBox(height: 10));
                          }

                          content.add(
                            Text(
                              t.tr('visitSummary'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                          content.add(const SizedBox(height: 6));
                          content.add(
                            Text(
                              sanitizedSummary.isNotEmpty
                                  ? sanitizedSummary
                                  : t.tr('noData'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                          content.add(const SizedBox(height: 10));
                        }

                        content.add(
                          Text(
                            t.tr('supervisorNotes'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                        content.add(const SizedBox(height: 8));

                        if (supervisorNotes.isEmpty) {
                          content.add(
                            Text(
                              t.tr('noData'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textLabel,
                              ),
                            ),
                          );
                        } else {
                          content.add(
                            Column(
                              children: supervisorNotes
                                  .map(
                                    (note) => Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.neutral50,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        border: Border.all(
                                          color: AppColors.neutral200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatDateTime(note.createdAt),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: AppColors.textLabel,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            note.content,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          );
                        }

                        content.add(const SizedBox(height: 10));

                        // Show client comments and input for ALL visits (not only completed)
                        content.add(
                          Text(
                            t.tr('clientComments'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                        content.add(const SizedBox(height: 8));

                        if (comments.isEmpty) {
                          content.add(
                            Text(
                              t.tr('noClientCommentsYet'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textLabel,
                              ),
                            ),
                          );
                        } else {
                          content.add(
                            Column(
                              children: comments
                                  .map(
                                    (comment) => Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.neutral50,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        border: Border.all(
                                          color: AppColors.neutral200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment.authorName ??
                                                t.tr('client'),
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatDateTime(comment.createdAt),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: AppColors.textLabel,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            comment.comment,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                          if (comment.attachmentPath != null &&
                                              comment.attachmentPath!
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            GestureDetector(
                                              onTap: () => _openMediaPreview(
                                                context,
                                                comment.attachmentPath!,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: _buildMediaThumbnail(
                                                  mediaPath:
                                                      comment.attachmentPath!,
                                                  size: 96,
                                                  radius: 8,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          );
                        }

                        content.add(const SizedBox(height: 6));

                        // Attachment preview
                        if (_pickedAttachmentPath != null) {
                          content.addAll([
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_pickedAttachmentPath!),
                                    width: 84,
                                    height: 84,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 84,
                                      height: 84,
                                      color: AppColors.neutral100,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: AppColors.textLabel,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => setState(
                                    () => _pickedAttachmentPath = null,
                                  ),
                                  icon: const Icon(Icons.close_rounded),
                                  tooltip: t.tr('remove'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ]);
                        }

                        // Comment input + pick image button
                        content.add(
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    labelText: t.tr('addClientComment'),
                                    hintText: t.tr('addClientCommentHint'),
                                    border: const OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      try {
                                        final picked = await _imagePicker
                                            .pickImage(
                                              source: ImageSource.gallery,
                                              maxWidth: 2048,
                                              imageQuality: 80,
                                            );
                                        if (picked != null) {
                                          setState(
                                            () => _pickedAttachmentPath =
                                                picked.path,
                                          );
                                        }
                                      } catch (e) {
                                        await _showCommentErrorDialog(
                                          sheetContext,
                                          t,
                                          e.toString(),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.photo_library_outlined,
                                    ),
                                    tooltip: t.tr('chooseFromGallery'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );

                        content.add(const SizedBox(height: 8));
                        content.add(
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FilledButton.icon(
                              onPressed: _isSubmittingComment
                                  ? null
                                  : () async {
                                      final input = _commentController.text
                                          .trim();
                                      if (input.isEmpty &&
                                          (_pickedAttachmentPath == null ||
                                              _pickedAttachmentPath!
                                                  .trim()
                                                  .isEmpty)) {
                                        await _showCommentErrorDialog(
                                          sheetContext,
                                          t,
                                          t.tr('commentRequired'),
                                        );
                                        return;
                                      }

                                      setState(
                                        () => _isSubmittingComment = true,
                                      );
                                      final saved = await clientProvider
                                          .submitVisitComment(
                                            contractId: visit.contractId,
                                            visitId: visit.id,
                                            comment: input,
                                            attachmentFilePath:
                                                _pickedAttachmentPath,
                                          );

                                      if (mounted) {
                                        setState(
                                          () => _isSubmittingComment = false,
                                        );
                                      }

                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }

                                      if (saved == null) {
                                        final backendError =
                                            clientProvider.errorMessage;
                                        final errorText =
                                            backendError != null &&
                                                backendError.trim().isNotEmpty
                                            ? '${t.tr('commentSubmitFailed')}: $backendError'
                                            : t.tr('commentSubmitFailed');
                                        await _showCommentErrorDialog(
                                          sheetContext,
                                          t,
                                          errorText,
                                        );
                                        return;
                                      }

                                      _commentController.clear();
                                      setState(
                                        () => _pickedAttachmentPath = null,
                                      );
                                      FocusScope.of(sheetContext).unfocus();
                                      ScaffoldMessenger.of(
                                        sheetContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            t.tr('visitCommentSaved'),
                                          ),
                                        ),
                                      );
                                    },
                              icon: _isSubmittingComment
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(t.tr('submitComment')),
                            ),
                          ),
                        );
                        content.add(const SizedBox(height: 12));

                        if (visit.gpsLat != null && visit.gpsLng != null) {
                          content.add(
                            OutlinedButton.icon(
                              onPressed: () async {
                                final lat = visit.gpsLat!;
                                final lng = visit.gpsLng!;
                                final geoUrl = Uri.parse(
                                  'geo:$lat,$lng?q=$lat,$lng',
                                );
                                final openedGeo = await launchUrl(
                                  geoUrl,
                                  mode: LaunchMode.externalApplication,
                                );
                                if (!openedGeo && sheetContext.mounted) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(t.tr('openMapFailed')),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.location_on_outlined),
                              label: Text(
                                t.locale.languageCode == 'ar'
                                    ? 'فتح الموقع'
                                    : 'Open location',
                              ),
                            ),
                          );
                          content.add(const SizedBox(height: 10));
                        }

                        content.add(
                          Text(
                            t.tr('tasks'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                        content.add(const SizedBox(height: 8));

                        if (tasksForVisit.isEmpty) {
                          content.add(
                            Text(
                              t.tr('noTasks'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textLabel,
                              ),
                            ),
                          );
                        } else {
                          for (final task in tasksForVisit) {
                            final taskExecutions = executions
                                .where((e) => e.taskId == task.id)
                                .toList();
                            final photosForTask = taskPhotos
                                .where(
                                  (p) => taskExecutions.any(
                                    (e) => e.id == p.executionId,
                                  ),
                                )
                                .toList();

                            content.add(
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.neutral50,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  border: Border.all(
                                    color: AppColors.neutral200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(task.title)),
                                        StatusChip.taskStatus(
                                          task.status,
                                          _taskStatusLabel(t, task.status),
                                        ),
                                      ],
                                    ),
                                    if (taskExecutions.any(
                                      (e) => (e.notes ?? '').trim().isNotEmpty,
                                    )) ...[
                                      const SizedBox(height: 6),
                                      ...taskExecutions
                                          .where(
                                            (e) => (e.notes ?? '')
                                                .trim()
                                                .isNotEmpty,
                                          )
                                          .map(
                                            (e) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                e.notes!,
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ),
                                          ),
                                    ],
                                    if (photosForTask.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        height: 70,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: photosForTask.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 6),
                                          itemBuilder: (context, index) {
                                            final p = photosForTask[index];
                                            return GestureDetector(
                                              onTap: () => _openMediaPreview(
                                                context,
                                                p.photoPath,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: _buildMediaThumbnail(
                                                  mediaPath: p.photoPath,
                                                  size: 70,
                                                  radius: 8,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }
                        }

                        content.add(const SizedBox(height: 8));
                        content.add(
                          Text(
                            t.tr('photos'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                        content.add(const SizedBox(height: 8));

                        if (directPhotos.isEmpty && taskPhotos.isEmpty) {
                          content.add(
                            Text(
                              t.tr('noPhotos'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textLabel,
                              ),
                            ),
                          );
                        } else {
                          final allPhotos = <String>[
                            ...directPhotos.map((p) => p.photoPath),
                            ...taskPhotos.map((p) => p.photoPath),
                          ];
                          content.add(
                            SizedBox(
                              height: 96,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: allPhotos.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final path = allPhotos[index];
                                  return GestureDetector(
                                    onTap: () =>
                                        _openMediaPreview(context, path),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: _buildMediaThumbnail(
                                        mediaPath: path,
                                        size: 96,
                                        radius: 10,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: content,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (widget.visits.isEmpty &&
        widget.terms.where((term) => !term.isExcluded).isEmpty) {
      return Center(child: Text(t.tr('noVisits')));
    }

    final groupedVisits = _buildGroups(
      t,
    ).where((group) => group.visits.isNotEmpty).toList();
    if (groupedVisits.isEmpty) {
      return Center(child: Text(t.tr('noVisits')));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: groupedVisits.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final group = groupedVisits[index];
        return _ClientVisitGroupSection(
          group: group,
          theme: theme,
          t: t,
          tasksForVisit: _tasksForVisit,
          onVisitTap: (visit) => _openVisitDetails(context, visit),
        );
      },
    );
  }

  List<_ClientVisitGroup> _buildGroups(AppLocalizations t) {
    final activeTerms = widget.terms.where((term) => !term.isExcluded).toList()
      ..sort((a, b) => a.activationOrder.compareTo(b.activationOrder));

    if (activeTerms.isEmpty) {
      final fallback = <String, List<Visit>>{};
      final meta = <String, ({String title, String? description})>{};

      for (final visit in widget.visits) {
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
        return _ClientVisitGroup(
          key: entry.key,
          title: itemMeta.title,
          description: itemMeta.description,
          visits: entry.value,
        );
      }).toList();
    }

    final usedVisitIds = <String>{};
    final groups = <_ClientVisitGroup>[];

    for (var index = 0; index < activeTerms.length; index++) {
      final term = activeTerms[index];
      final termContent = term.content.trim();

      // Mirror dashboard logic: match visits by title == term content
      final matchedVisits = widget.visits.where((visit) {
        if (usedVisitIds.contains(visit.id)) return false;
        return (visit.title ?? '').trim() == termContent;
      }).toList();

      usedVisitIds.addAll(matchedVisits.map((visit) => visit.id));

      groups.add(
        _ClientVisitGroup(
          key: 'term_$index',
          title: termContent.isNotEmpty
              ? termContent
              : '${t.tr('generalVisitsItem')} ${index + 1}',
          description: null,
          visits: matchedVisits,
        ),
      );
    }

    final unmatchedVisits = widget.visits
        .where((visit) => !usedVisitIds.contains(visit.id))
        .toList();
    if (unmatchedVisits.isNotEmpty) {
      groups.add(
        _ClientVisitGroup(
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

class _ClientVisitGroup {
  final String key;
  final String title;
  final String? description;
  final List<Visit> visits;

  const _ClientVisitGroup({
    required this.key,
    required this.title,
    required this.description,
    required this.visits,
  });
}

class _ClientVisitGroupSection extends StatelessWidget {
  final _ClientVisitGroup group;
  final ThemeData theme;
  final AppLocalizations t;
  final List<ContractTask> Function(String visitId) tasksForVisit;
  final void Function(Visit visit) onVisitTap;

  const _ClientVisitGroupSection({
    required this.group,
    required this.theme,
    required this.t,
    required this.tasksForVisit,
    required this.onVisitTap,
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
                child: _ClientVisitCard(
                  visit: visit,
                  theme: theme,
                  t: t,
                  tasks: tasksForVisit(visit.id),
                  onTap: () => onVisitTap(visit),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ClientVisitCard extends StatelessWidget {
  final Visit visit;
  final ThemeData theme;
  final AppLocalizations t;
  final List<ContractTask> tasks;
  final VoidCallback onTap;

  const _ClientVisitCard({
    required this.visit,
    required this.theme,
    required this.t,
    required this.tasks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completedTasks = tasks
        .where((task) => task.isCompleted || task.isVerified)
        .length;
    final hasDescription =
        visit.description != null && visit.description!.trim().isNotEmpty;

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
          onTap: onTap,
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
                            _visitDisplayTitle(t, visit),
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
                            _visitStatusLabel(t, visit.status),
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
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF15803d),
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
                if (hasDescription) ...[
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

String _taskStatusLabel(AppLocalizations t, String status) {
  return switch (status) {
    'pending' => t.tr('pendingStatus'),
    'completed' => t.tr('completedStatus'),
    'verified' => t.tr('verifiedStatus'),
    'rejected' => t.tr('rejectedStatus'),
    _ => status,
  };
}

class _NetworkVideoPreview extends StatefulWidget {
  final String videoUrl;

  const _NetworkVideoPreview({required this.videoUrl});

  @override
  State<_NetworkVideoPreview> createState() => _NetworkVideoPreviewState();
}

class _NetworkVideoPreviewState extends State<_NetworkVideoPreview> {
  VideoPlayerController? _controller;
  bool _initError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null) {
      if (mounted) setState(() => _initError = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.setLooping(true);

    try {
      await controller.initialize();
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _initError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return SizedBox(
      height: 420,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _initError
                  ? const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 42,
                      ),
                    )
                  : (controller == null || !controller.value.isInitialized)
                  ? const Center(child: CircularProgressIndicator())
                  : GestureDetector(
                      onTap: _togglePlayPause,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          if (controller != null && controller.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                color: Colors.black.withValues(alpha: 0.45),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white54,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        controller.value.isPlaying
                            ? Icons.pause_circle_rounded
                            : Icons.play_circle_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
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

class _TermsTab extends StatelessWidget {
  final List<ContractTerm> terms;

  const _TermsTab({required this.terms});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final activeTerms = terms.where((term) => !term.isExcluded).toList();
    if (activeTerms.isEmpty) {
      return Center(child: Text(t.tr('noTerms')));
    }

    // Sort active terms by activationOrder (dashboard ordering)
    activeTerms.sort((a, b) => a.activationOrder.compareTo(b.activationOrder));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...activeTerms.map(
          (term) => Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(term.content, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PalmInfoCard extends StatelessWidget {
  final ContractPalmInfo palmInfo;

  const _PalmInfoCard({required this.palmInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBaladi = (palmInfo.species ?? 'baladi') == 'baladi';
    final stats = isBaladi ? palmInfo.baladi : palmInfo.washingtonia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.55,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isBaladi ? 'النوع: بلدي' : 'النوع: واشنطونيا',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _InfoRow(label: 'كبير ومثمر', value: '${stats.largeProductive}'),
        _InfoRow(label: 'كبير وغير مثمر', value: '${stats.largeNonProductive}'),
        _InfoRow(label: 'صغير ومثمر', value: '${stats.smallProductive}'),
        _InfoRow(label: 'صغير وغير مثمر', value: '${stats.smallNonProductive}'),
      ],
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallInfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(AppLocalizations t, String status) {
  return switch (status) {
    'active' => t.tr('statusActive'),
    'pending' => t.tr('statusPending'),
    'terminated' => t.tr('statusTerminated'),
    'expired' => t.tr('statusExpired'),
    'completed' => t.tr('completedStatus'),
    _ => status,
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'active' => Colors.green,
    'pending' => Colors.orange,
    'terminated' => Colors.red,
    'expired' => Colors.grey,
    'completed' => Colors.blue,
    _ => Colors.grey,
  };
}

String _visitStatusLabel(AppLocalizations t, String status) {
  return switch (status) {
    'completed' => t.locale.languageCode == 'ar' ? 'مكتملة' : 'Completed',
    'planned' => t.locale.languageCode == 'ar' ? 'لم تكتمل' : 'Not completed',
    'in_progress' =>
      t.locale.languageCode == 'ar' ? 'لم تكتمل' : 'Not completed',
    'cancelled' => t.locale.languageCode == 'ar' ? 'لم تكتمل' : 'Not completed',
    _ => status,
  };
}

String _visitDisplayTitle(AppLocalizations t, Visit visit) {
  final notes = (visit.notes ?? '').trim();
  if (notes.isNotEmpty) return notes;

  final description = (visit.description ?? '').trim();
  if (description.isNotEmpty) return description;

  final title = (visit.title ?? '').trim();
  if (title.isNotEmpty) return title;

  return t.tr('visitDetails');
}

String _sanitizeVisitSummary(String? summary) {
  final source = (summary ?? '').trim();
  if (source.isEmpty) return '';

  final withoutMapLinks = source
      .replaceAll(
        RegExp(
          r'https?:\/\/(?:www\.)?(?:maps\.google\.[^\s\/]+|google\.com\/maps|maps\.app\.goo\.gl|goo\.gl\/maps)[^\s]*',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'geo:[^\s]+', caseSensitive: false), '');

  final withoutMapText = withoutMapLinks.replaceAll(
    RegExp(r'google\s*maps\s*:?\s*', caseSensitive: false),
    '',
  );

  return withoutMapText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

String _formatVisitDate(String? iso) {
  if (iso == null || iso.trim().isEmpty) return '---';
  final date = DateTime.tryParse(iso);
  if (date == null) return '---';
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '${local.year}/$month/$day ${date_fmt.formatTime(local)}';
}

String _formatCurrency(AppLocalizations t, double amount) {
  return '${amount.toStringAsFixed(2)} ${t.tr('currencyKwd')}';
}
