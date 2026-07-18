import 'package:flutter/material.dart';
import 'package:bustan_amari/core/theme/app_colors.dart';

ThemeData buildAdminTheme(ThemeData base) {
  final colorScheme = base.colorScheme.copyWith(
    primary: AppColors.primary700,
    onPrimary: AppColors.cardBackground,
    secondary: AppColors.accent500,
    onSecondary: AppColors.cardBackground,
    surface: AppColors.cardBackground,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textLabel,
    primaryContainer: AppColors.primary100,
    onPrimaryContainer: AppColors.primary700,
    secondaryContainer: AppColors.neutral100,
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.info,
    onTertiary: AppColors.cardBackground,
    tertiaryContainer: AppColors.infoLight,
    onTertiaryContainer: AppColors.textPrimary,
    error: AppColors.error,
    onError: AppColors.cardBackground,
    errorContainer: AppColors.errorLight,
    onErrorContainer: AppColors.error,
    outline: AppColors.neutral200,
    outlineVariant: AppColors.neutral200,
    surfaceContainerLow: AppColors.cardBackground,
    surfaceContainerHighest: AppColors.neutral100,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: base.cardTheme.copyWith(
      color: AppColors.cardBackground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.neutral200),
      ),
    ),
    dividerColor: AppColors.neutral200,
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: AppColors.cardBackground,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.neutral200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary700, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.neutral200),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.neutral100,
      selectedColor: AppColors.primary100,
      side: const BorderSide(color: AppColors.neutral200),
      labelStyle: base.textTheme.labelMedium?.copyWith(
        color: AppColors.textLabel,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: base.textTheme.labelMedium?.copyWith(
        color: AppColors.primary700,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: AppColors.cardBackground,
      indicatorColor: AppColors.primary100,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary700);
        }
        return const IconThemeData(color: AppColors.textLabel);
      }),
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
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary700,
    ),
  );
}
