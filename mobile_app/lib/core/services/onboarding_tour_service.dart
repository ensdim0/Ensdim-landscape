import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/theme/app_colors.dart';
import 'package:ensdim_landscape/core/theme/app_dimensions.dart';

/// A single stop in a screen's onboarding tour: highlights [key]'s widget
/// with [title]/[description] text.
class TourStep {
  final GlobalKey key;
  final String title;
  final String description;
  final ShapeLightFocus shape;

  const TourStep({
    required this.key,
    required this.title,
    required this.description,
    this.shape = ShapeLightFocus.RRect,
  });
}

/// Builds and shows [TutorialCoachMark] overlays, and remembers (per user,
/// per screen) whether the tour has already been seen so it only
/// auto-plays once.
class OnboardingTourService {
  OnboardingTourService._();

  static String _seenKey(String userId, String screenId) =>
      'tour_seen_${userId}_$screenId';

  static Future<bool> hasSeen(String userId, String screenId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey(userId, screenId)) ?? false;
  }

  static Future<void> markSeen(String userId, String screenId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey(userId, screenId), true);
  }

  /// Shows the tour only if [userId] hasn't seen [screenId] before.
  static Future<void> showIfUnseen(
    BuildContext context, {
    required String userId,
    required String screenId,
    required List<TourStep> steps,
  }) async {
    if (steps.isEmpty) return;
    if (await hasSeen(userId, screenId)) return;
    if (!context.mounted) return;
    _show(context, steps, onFinish: () => markSeen(userId, screenId));
  }

  /// Shows the tour unconditionally (used by a manual "replay" button).
  static void forceShow(BuildContext context, List<TourStep> steps) {
    if (steps.isEmpty) return;
    _show(context, steps);
  }

  static void _show(
    BuildContext context,
    List<TourStep> steps, {
    VoidCallback? onFinish,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final targets = <TargetFocus>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final isLast = i == steps.length - 1;
      targets.add(
        TargetFocus(
          identify: step.title,
          keyTarget: step.key,
          shape: step.shape,
          radius: AppRadius.md,
          contents: [
            TargetContent(
              // Place the card on whichever side of the target has more
              // room, based on the target's actual on-screen position —
              // a fixed alignment would land on top of (or far away from)
              // whatever it's supposed to be explaining.
              align: _resolveAlign(step.key, screenHeight),
              padding: const EdgeInsets.all(AppSpacing.lg),
              builder: (context, controller) => _TourContentCard(
                step: step,
                isLast: isLast,
                controller: controller,
              ),
            ),
          ],
        ),
      );
    }

    final t = AppLocalizations.of(context);
    TutorialCoachMark(
      targets: targets,
      colorShadow: AppColors.primary900,
      opacityShadow: 0.8,
      textSkip: t.tr('tourSkip'),
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      // Scrolls the target into view first in case it's below the fold
      // (e.g. the contracts section on a long list) before focusing it.
      beforeFocus: (target) async {
        final targetContext = target.keyTarget?.currentContext;
        if (targetContext == null) return;
        await Scrollable.ensureVisible(
          targetContext,
          duration: AppDurations.normal,
          curve: AppCurves.easeOut,
          alignment: 0.3,
        );
      },
      onFinish: () {
        onFinish?.call();
        return true;
      },
      onSkip: () {
        onFinish?.call();
        return true;
      },
      onClickTarget: (_) {},
    ).show(context: context);
  }

  static ContentAlign _resolveAlign(GlobalKey key, double screenHeight) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.attached) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final centerY = topLeft.dy + renderObject.size.height / 2;
      // Target sits in the lower part of the screen (e.g. the bottom nav
      // bar) — show the card above it instead of below the screen edge.
      if (centerY > screenHeight * 0.62) return ContentAlign.top;
    }
    return ContentAlign.bottom;
  }
}

class _TourContentCard extends StatelessWidget {
  final TourStep step;
  final bool isLast;
  final TutorialCoachMarkController controller;

  const _TourContentCard({
    required this.step,
    required this.isLast,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Align(
      // TargetContent always hands us the full screen width, so on
      // tablets/large screens we cap and center the card instead of
      // letting it stretch edge-to-edge.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                step.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                step.description,
                style: const TextStyle(
                  color: AppColors.textLabel,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => controller.next(),
                child: Text(isLast ? t.tr('tourFinish') : t.tr('tourNext')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
