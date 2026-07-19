// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/theme/app_dimensions.dart';

class SocialIconsBar extends StatelessWidget {
  final Color iconColor;
  final double iconSize;
  const SocialIconsBar({
    super.key,
    this.iconColor = Colors.white,
    this.iconSize = 20.0,
  });

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.globe,
            color: iconColor,
            size: iconSize,
          ),
          onPressed: () => _launchUrl('https://www.ensdim.com/'),
          tooltip: t.tr('website'),
        ),
      ],
    );
  }
}

class ContactFooterBar extends StatelessWidget {
  final Color textColor;
  const ContactFooterBar({super.key, this.textColor = Colors.white});

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
    final t = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          t.tr('contactUs'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: InkWell(
                onTap: () => _makePhoneCall('+201060162694'),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.headset_mic_rounded,
                        size: 16,
                        color: textColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${t.tr('complaints')}: 201060162694',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: InkWell(
                onTap: () => _sendEmail('contact@ensdim.com'),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email_outlined, size: 16, color: textColor),
                      const SizedBox(width: 4),
                      Text(
                        'contact@ensdim.com',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
