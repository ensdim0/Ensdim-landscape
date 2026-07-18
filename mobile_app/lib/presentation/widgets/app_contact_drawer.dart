import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';
import 'package:bustan_amari/core/theme/app_dimensions.dart';

class AppContactDrawer extends StatelessWidget {
  const AppContactDrawer({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A standard material drawer
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header with App Info / Icons on Top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xl,
                horizontal: AppSpacing.lg,
              ),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(bottom: BorderSide(color: AppColors.neutral200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary50,
                    ),
                    child: const Icon(
                      Icons.park_rounded,
                      size: 40,
                      color: AppColors.primary700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'بستان اماري',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Social Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.facebookF,
                          color: Colors.blue,
                        ),
                        onPressed: () =>
                            _launchUrl('https://facebook.com/bustanamary'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.instagram,
                          color: Colors.purple,
                        ),
                        onPressed: () =>
                            _launchUrl('https://instagram.com/bustanamary'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.tiktok,
                          color: Colors.black87,
                        ),
                        onPressed: () =>
                            _launchUrl('https://tiktok.com/@bustanamary'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Expanded space for whatever menu items the app currently has
            const Spacer(),

            // Drawer Footer with Email and Complaints Number
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.primary50,
                border: Border(top: BorderSide(color: AppColors.primary100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'تواصل معنا',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ContactRow(
                    icon: Icons.headset_mic_rounded,
                    title: 'رقم الشكاوى',
                    value: '+96599423149',
                    onTap: () => _makePhoneCall('+96599423149'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ContactRow(
                    icon: Icons.email_rounded,
                    title: 'البريد الإلكتروني',
                    value:
                        'info@bustanamary.com', // generic email, can be updated
                    onTap: () => _sendEmail('info@bustanamary.com'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary600),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
