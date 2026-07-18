import 'package:flutter/material.dart';

/// Centralized color palette matching the Dashboard design system
/// Colors sync with dashboard/src/presentation/styles/base.css
class AppColors {
  AppColors._();

  // Primary Green Palette (matching dashboard --green-*)
  static const Color primary50 = Color(0xFFF4F7F2);
  static const Color primary100 = Color(0xFFE3EBE0);
  static const Color primary200 = Color(0xFFCBDAC6);
  static const Color primary300 = Color(0xFFA8C2A3);
  static const Color primary400 = Color(0xFF7FA680);
  static const Color primary500 = Color(0xFF5A8C5E);
  static const Color primary600 = Color(0xFF4A7451);
  static const Color primary700 = Color(0xFF30461F); // Main brand color
  static const Color primary800 = Color(0xFF3E6530); // Login gradient darker
  static const Color primary900 = Color(0xFF2E5C1F); // Login gradient darkest
  static const Color primary950 = Color(0xFF111A0C);

  // Secondary Orange/Accent Palette (matching dashboard --orange-*)
  static const Color accent50 = Color(0xFFFEF8F2);
  static const Color accent100 = Color(0xFFFDEADD);
  static const Color accent200 = Color(0xFFFBCBAE);
  static const Color accent300 = Color(0xFFF9A97E);
  static const Color accent400 = Color(0xFFF5834E);
  static const Color accent500 = Color(0xFFEA8E20); // Main accent
  static const Color accent600 = Color(0xFFD87B15);
  static const Color accent700 = Color(0xFFBC640E);
  static const Color accent800 = Color(0xFF9D4D0B);
  static const Color accent900 = Color(0xFF7D3A08);
  static const Color accent950 = Color(0xFF3D1809);

  // Neutral Palette (matching dashboard --neutral-*)
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFBFAF9); // App background
  static const Color neutral100 = Color(0xFFF5F2F0);
  static const Color neutral200 = Color(0xFFEBE6E1);
  static const Color neutral300 = Color(0xFFE0D8D1);
  static const Color neutral400 = Color(0xFFCDBDB2);
  static const Color neutral500 = Color(0xFFB19E93);
  static const Color neutral600 = Color(0xFF8B7A6F);
  static const Color neutral700 = Color(0xFF5C574F);
  static const Color neutral800 = Color(0xFF3A3632);
  static const Color neutral900 = Color(0xFF1A1917);

  // Semantic Color Aliases (for convenience)
  static const Color primary = primary700;
  static const Color secondary = accent500;
  static const Color accent = accent500;
  static const Color background = neutral50;
  static const Color surface = neutral0;
  static const Color cardBackground = neutral0;

  // Text Colors
  static const Color textPrimary = Color(0xFF22301A); // Dark green
  static const Color textLabel = neutral700;
  static const Color textPlaceholder = Color(0xFFC0ADAA); // Muted tan
  static const Color textSecondary = neutral600;

  // Status Colors
  static const Color error = Color(0xFFC41E3A);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color warning = Color(0xFFFB8500);
  static const Color warningLight = Color(0xFFFFF3CD);
  static const Color success = Color(0xFF2ECC71);
  static const Color successLight = Color(0xFfd4edda);
  static const Color info = Color(0xFF0084D4);
  static const Color infoLight = Color(0xFFd1ecf1);
}
