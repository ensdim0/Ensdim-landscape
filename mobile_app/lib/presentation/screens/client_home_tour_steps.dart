import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:ensdim_landscape/core/l10n/app_localizations.dart';
import 'package:ensdim_landscape/core/services/onboarding_tour_service.dart';

/// Builds the onboarding tour steps for [ClientHomeScreen]'s dashboard tab.
/// Every key here must be mounted (i.e. the dashboard tab must be the
/// currently visible tab, with data already loaded) when the tour runs.
List<TourStep> buildClientHomeTourSteps(
  BuildContext context, {
  required GlobalKey summaryKey,
  required GlobalKey quickAccessKey,
  required GlobalKey contractsKey,
  required GlobalKey navKey,
  required GlobalKey helpKey,
}) {
  final t = AppLocalizations.of(context);

  return [
    TourStep(
      key: summaryKey,
      title: t.tr('tourHomeSummaryTitle'),
      description: t.tr('tourHomeSummaryDesc'),
    ),
    TourStep(
      key: quickAccessKey,
      title: t.tr('tourHomeQuickAccessTitle'),
      description: t.tr('tourHomeQuickAccessDesc'),
    ),
    TourStep(
      key: contractsKey,
      title: t.tr('tourHomeContractsTitle'),
      description: t.tr('tourHomeContractsDesc'),
    ),
    TourStep(
      key: navKey,
      title: t.tr('tourHomeNavTitle'),
      description: t.tr('tourHomeNavDesc'),
      shape: ShapeLightFocus.RRect,
    ),
    TourStep(
      key: helpKey,
      title: t.tr('tourHomeHelpTitle'),
      description: t.tr('tourHomeHelpDesc'),
    ),
  ];
}
