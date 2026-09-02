import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/presentation/widgets/app_message_view.dart';
import '../../../../core/presentation/widgets/readable_width.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/router/routes.dart';
import '../add_court_flow.dart';
import '../browse_city_provider.dart';
import '../browsing_area.dart';
import '../nearby_courts_notifier.dart';
import '../widgets/court_card.dart';
import '../widgets/court_error_view.dart';
import '../widgets/court_list_skeleton.dart';

class CourtsListPage extends ConsumerWidget {
  const CourtsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtsAsync = ref.watch(nearbyCourtsProvider);
    final city = ref.watch(browseCityProvider);

    return Scaffold(
      appBar: AppBar(
        // The title says where the courts are from, because with a city
        // picked they are not "near you" at all.
        title: Text(
          city == null
              ? AppStrings.courtsListTitle
              : AppStrings.browsingCity(city.name),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_city_outlined),
            tooltip: AppStrings.browseACity,
            onPressed: () => context.pushNamed(Routes.pickCityName),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppStrings.settingsTooltip,
            onPressed: () => context.pushNamed(Routes.settingsName),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openAddCourtFlow(context, ref),
        tooltip: AppStrings.addCourtTooltip,
        child: const Icon(Icons.add),
      ),
      body: ReadableWidth(
        child: courtsAsync.when(
          loading: () => const CourtListSkeleton(),
          error: (error, stackTrace) => CourtErrorView(
            error: error,
            onRetry: () => ref.invalidate(nearbyCourtsProvider),
          ),
          data: (courts) {
            if (courts.isEmpty) {
              final area = ref.watch(browsingAreaProvider);
              final radius = AppStrings.settingsRadiusLabel(
                ref.watch(searchRadiusProvider),
              );

              // An empty search is the app's best moment to ask for a
              // contribution: the user is looking at a place they know, and
              // they have just been told nobody has mapped it. Refreshing is
              // the weaker answer, so it moves below.
              return AppEmptyView(
                icon: Icons.sports_basketball_outlined,
                title: AppStrings.noCourtsNearbyTitle,
                message: switch (area) {
                  null => AppStrings.noCourtsNearbyListMessage(radius),
                  BrowsingArea(cityName: final name?) =>
                    AppStrings.noCourtsAroundListMessage(name, radius),
                  _ => AppStrings.noCourtsInAreaListMessage(radius),
                },
                actionLabel: AppStrings.addFirstCourt,
                actionIcon: Icons.add_location_alt_outlined,
                onAction: () => openAddCourtFlow(context, ref),
                secondaryActionLabel: AppStrings.refresh,
                onSecondaryAction: () => ref.invalidate(nearbyCourtsProvider),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(nearbyCourtsProvider),
              child: ListView.separated(
                // Extra bottom padding so the last card clears the floating
                // action button instead of sitting under it.
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxxl * 2,
                ),
                itemCount: courts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final courtWithDistance = courts[index];
                  return CourtCard(
                    courtWithDistance: courtWithDistance,
                    onTap: () => context.pushNamed(
                      Routes.courtDetailName,
                      pathParameters: {
                        Routes.courtIdParam: courtWithDistance.court.id,
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
