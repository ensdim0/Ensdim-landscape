// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:bustan_amari/core/l10n/app_localizations.dart';
import 'package:bustan_amari/core/theme/app_dimensions.dart';

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
            FontAwesomeIcons.facebookF,
            color: iconColor,
            size: iconSize,
          ),
          onPressed: () => _launchUrl(
            'https://www.facebook.com/share/1CE8zN5Hru/?mibextid=wwXIfr',
          ),
          tooltip: t.tr('facebook'),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.instagram,
            color: iconColor,
            size: iconSize,
          ),
          onPressed: () => _launchUrl(
            'https://www.instagram.com/bustanamari.kw?igsh=Z3V2Y2Q3em8xZXhs',
          ),
          tooltip: t.tr('instagram'),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.tiktok,
            color: iconColor,
            size: iconSize,
          ),
          onPressed: () => _launchUrl('https://www.tiktok.com/@bustanamari'),
          tooltip: t.tr('tiktok'),
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
                onTap: () => _makePhoneCall('+96599423149'),
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
                        '${t.tr('complaints')}: 96599423149',
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
                onTap: () => _sendEmail('info@bustanamary.com'),
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
                        'info@bustanamary.com',
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
