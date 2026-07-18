import 'package:flutter/material.dart';

/// Border radius values matching dashboard design system
/// Corresponds to dashboard --radius-* CSS variables
class AppRadius {
  AppRadius._();

  static const double xs = 6.0; // --radius-sm (smallest inputs, badges)
  static const double sm = 6.0; // alias for xs
  static const double md = 10.0; // --radius-md (cards, buttons)
  static const double lg = 16.0; // --radius-lg (modals, dialogs, large cards)
  static const double xl = 20.0; // larger radius
  static const double full = 9999.0; // BorderRadius.circular(9999) = circle
}

/// Shadow definitions matching dashboard CSS shadows
/// Shadows use green-tinted colors for consistency with dashboard aesthetic
class AppShadows {
  AppShadows._();

  /// Extra small shadow (dashboard: --shadow-xs)
  /// Used for subtle elevation on small elements
  static const BoxShadow xs = BoxShadow(
    color: Color.fromARGB(13, 49, 71, 32), // rgba(49, 71, 32, 0.05)
    blurRadius: 2,
    offset: Offset(0, 1),
  );

  /// Small shadow (dashboard: --shadow-sm)
  /// Used for cards and input fields
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color.fromARGB(13, 49, 71, 32), // rgba(49, 71, 32, 0.05)
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  /// Medium shadow (dashboard: --shadow-md)
  /// Standard elevation for cards, buttons
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color.fromARGB(26, 49, 71, 32), // rgba(49, 71, 32, 0.1)
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Large shadow (dashboard: --shadow-lg)
  /// Elevated cards, prominent components
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color.fromARGB(26, 49, 71, 32), // rgba(49, 71, 32, 0.1)
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Orange-tinted shadow for accent elements (matching dashboard)
  static const BoxShadow accentShadow = BoxShadow(
    color: Color.fromARGB(77, 234, 142, 32), // rgba(234, 142, 32, 0.3)
    blurRadius: 12,
    offset: Offset(0, 4),
  );
}

/// Spacing/Padding constants for consistent layout
class AppSpacing {
  AppSpacing._();

  static const double none = 0.0;
  static const double xs = 4.0; // Minimal spacing
  static const double sm = 8.0; // Small spacing
  static const double md = 12.0; // Medium spacing (field gaps)
  static const double lg = 16.0; // Large spacing (section padding)
  static const double xl = 24.0; // Extra large spacing (card padding)
  static const double xxl = 32.0; // 2xl spacing
  static const double xxxl = 48.0; // 3xl spacing
}

/// Common EdgeInsetious for consistent layouts
class AppPadding {
  AppPadding._();

  static const EdgeInsets none = EdgeInsets.zero;

  // All sides symmetric
  static const EdgeInsets xs = EdgeInsets.all(AppSpacing.xs);
  static const EdgeInsets sm = EdgeInsets.all(AppSpacing.sm);
  static const EdgeInsets md = EdgeInsets.all(AppSpacing.md);
  static const EdgeInsets lg = EdgeInsets.all(AppSpacing.lg);
  static const EdgeInsets xl = EdgeInsets.all(AppSpacing.xl);

  // Horizontal/Vertical pairs
  static const EdgeInsets h8v12 = EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: AppSpacing.md,
  );

  static const EdgeInsets h16v12 = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );
}

/// Duration constants for animations
class AppDurations {
  AppDurations._();

  static const Duration fastest = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration slowest = Duration(milliseconds: 1000);
}

/// Common curves for animations
class AppCurves {
  AppCurves._();

  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve linear = Curves.linear;
}

/// Elevation constants for Material components
class AppElevation {
  AppElevation._();

  static const double card = 1.0;
  static const double button = 0.0;
  static const double fab = 6.0;
  static const double dialog = 4.0;
  static const double appBar = 0.0;
  static const double modal = 8.0;
}
