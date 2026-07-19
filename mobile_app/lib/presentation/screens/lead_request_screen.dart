import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/core/theme/app_dimensions.dart';
import 'package:ensdim_landscape/presentation/widgets/app_text_field.dart';
import 'package:ensdim_landscape/presentation/providers/locale_provider.dart';
import 'package:ensdim_landscape/presentation/widgets/global_contact_bars.dart';

class LeadRequestScreen extends StatefulWidget {
  const LeadRequestScreen({super.key});

  @override
  State<LeadRequestScreen> createState() => _LeadRequestScreenState();
}

class _LeadRequestScreenState extends State<LeadRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitLead() async {
    final t = AppLocalizations.of(context);
    final supabase = Supabase.instance.client;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await supabase.from('contact_requests').insert({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'source': 'mobile_app',
      });

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.tr('leadRequestSuccess')),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.tr('leadRequestFailed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.tr('leadRequestTitle')),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.read<LocaleProvider>().toggleLocale(),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        size: 20,
                        color: AppColors.primary700,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        t.tr('switchLanguage'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.tr('leadRequestGreeting'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                t.tr('leadRequestSubtitle'),
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      controller: _nameController,
                      labelText: t.tr('leadRequestNameLabel'),
                      hintText: t.tr('leadRequestNameHint'),
                      prefixIcon: Icons.person_outline,
                      enabled: !_isLoading,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return t.tr('leadRequestNameRequired');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _phoneController,
                      labelText: t.tr('leadRequestPhoneLabel'),
                      hintText: t.tr('leadRequestPhoneHint'),
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      enabled: !_isLoading,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return t.tr('leadRequestPhoneRequired');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _notesController,
                      labelText: t.tr('leadRequestNotesLabel'),
                      hintText: t.tr('leadRequestNotesHint'),
                      prefixIcon: Icons.notes_outlined,
                      maxLines: 3,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submitLead,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                t.tr('leadRequestSubmit'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const Divider(color: AppColors.neutral200),
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      t.tr('leadRequestFollowUs'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary800,
                      ),
                    ),
                    SocialIconsBar(
                      iconColor: AppColors.primary700,
                      iconSize: 24.0,
                    ),
                    ContactFooterBar(textColor: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
