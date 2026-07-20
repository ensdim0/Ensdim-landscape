import 'package:flutter/material.dart';

/// Centralized color palette matching the Dashboard design system
/// Colors sync with dashboard/src/presentation/styles/base.css
class AppColors {
  AppColors._();

  // Primary Purple Palette (matching dashboard --purple-*)
  static const Color primary50 = Color(0xFFF2F0F8);
  static const Color primary100 = Color(0xFFE2DDEF);
  static const Color primary200 = Color(0xFFC5BBDF);
  static const Color primary300 = Color(0xFFA190C9);
  static const Color primary400 = Color(0xFF7C68AC);
  static const Color primary500 = Color(0xFF5C4790);
  static const Color primary600 = Color(0xFF453375);
  static const Color primary700 = Color(0xFF2F2160); // Main brand color
  static const Color primary800 = Color(0xFF251A4C); // Login gradient darker
  static const Color primary900 = Color(0xFF1A1338); // Login gradient darkest
  static const Color primary950 = Color(0xFF100C22);

  // Secondary/Accent Palette — kept as the same purple family (a single
  // "live" brand hue): matching dashboard --purple-500 --color-accent
  static const Color accent50 = Color(0xFFF2F0F8);
  static const Color accent100 = Color(0xFFE2DDEF);
  static const Color accent200 = Color(0xFFC5BBDF);
  static const Color accent300 = Color(0xFFA190C9);
  static const Color accent400 = Color(0xFF7C68AC);
  static const Color accent500 = Color(0xFF5C4790); // Main accent
  static const Color accent600 = Color(0xFF453375);
  static const Color accent700 = Color(0xFF2F2160);
  static const Color accent800 = Color(0xFF251A4C);
  static const Color accent900 = Color(0xFF1A1338);
  static const Color accent950 = Color(0xFF100C22);

  // Neutral Palette (matching dashboard --neutral-*)
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFAFAFA); // App background
  static const Color neutral100 = Color(0xFFF0EFF2);
  static const Color neutral200 = Color(0xFFE1DFE6);
  static const Color neutral300 = Color(0xFFC7C4CF);
  static const Color neutral400 = Color(0xFF9A97A3);
  static const Color neutral500 = Color(0xFF706D7A);
  static const Color neutral600 = Color(0xFF524F5A);
  static const Color neutral700 = Color(0xFF3A3841);
  static const Color neutral800 = Color(0xFF24232A);
  static const Color neutral900 = Color(0xFF101318);

  // Semantic Color Aliases (for convenience)
  static const Color primary = primary700;
  static const Color secondary = accent500;
  static const Color accent = accent500;
  static const Color background = neutral50;
  static const Color surface = neutral0;
  static const Color cardBackground = neutral0;

  // Sidebar/app-bar-style chrome — solid ink black, matching the
  // dashboard's sidebar (see .sidebar in base.css)
  static const Color chrome = neutral900;

  // Text Colors
  static const Color textPrimary = neutral900;
  static const Color textLabel = neutral700;
  static const Color textPlaceholder = neutral400;
  static const Color textSecondary = neutral600;

  // Status Colors
  static const Color error = Color(0xFFC23030); // Brand red — also the danger color
  static const Color errorLight = Color(0xFFFBEAEA);
  static const Color warning = Color(0xFFA15B06);
  static const Color warningLight = Color(0xFFFDF1E0);
  static const Color success = Color(0xFF1F7A4D);
  static const Color successLight = Color(0xFFE6F4EC);
  static const Color info = Color(0xFF21579C);
  static const Color infoLight = Color(0xFFE8F0FB);
}
