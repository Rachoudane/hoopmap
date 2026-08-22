import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/presentation/widgets/app_message_view.dart';
import '../../../../core/terms/terms_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/router/routes.dart';
import '../court_error_messages.dart';
import '../nearby_courts_notifier.dart';
import '../widgets/court_card.dart';
import '../widgets/court_list_skeleton.dart';

class CourtsListPage extends ConsumerWidget {
  const CourtsListPage({super.key});

  // The Terms of Use must be accepted before the first court submission,
  // and there's no bypass: this FAB is the only in-app entry point to
  // AddCourtPage (its route isn't reachable via the hoopmap:// deep link,
  // see android/app/src/main/AndroidManifest.xml). Already-accepted users
  // go straight to the form, matching the previous behavior exactly.
  Future<void> _handleAddCourt(BuildContext context, WidgetRef ref) async {
    if (ref.read(termsAcceptedProvider)) {
      context.pushNamed(Routes.addCourtName);
      return;
    }
    final accepted = await context.pushNamed<bool>(Routes.termsAcceptName);
    if (accepted == true && context.mounted) {
      context.pushNamed(Routes.addCourtName);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtsAsync = ref.watch(nearbyCourtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.courtsListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: AppStrings.termsOfUseTooltip,
            onPressed: () => context.pushNamed(Routes.termsName),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleAddCourt(context, ref),
        tooltip: AppStrings.addCourtTooltip,
        child: const Icon(Icons.add),
      ),
      body: courtsAsync.when(
        loading: () => const CourtListSkeleton(),
        error: (error, stackTrace) => AppErrorView(
          message: courtErrorMessage(error),
          icon: courtErrorIcon(error),
          onRetry: () => ref.invalidate(nearbyCourtsProvider),
        ),
        data: (courts) {
          if (courts.isEmpty) {
            return AppEmptyView(
              icon: Icons.sports_basketball_outlined,
              title: AppStrings.noCourtsNearbyTitle,
              message: AppStrings.noCourtsNearbyListMessage,
              actionLabel: AppStrings.refresh,
              onAction: () => ref.invalidate(nearbyCourtsProvider),
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
    );
  }
}
