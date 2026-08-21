import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/widgets/app_message_view.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/router/routes.dart';
import '../court_error_messages.dart';
import '../nearby_courts_notifier.dart';
import '../widgets/court_card.dart';
import '../widgets/court_list_skeleton.dart';

class CourtsListPage extends ConsumerWidget {
  const CourtsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtsAsync = ref.watch(nearbyCourtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Terrains à proximité')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(Routes.addCourtName),
        tooltip: 'Ajouter un terrain',
        child: const Icon(Icons.add),
      ),
      body: courtsAsync.when(
        loading: () => const CourtListSkeleton(),
        error: (error, stackTrace) => AppErrorView(
          message: courtErrorMessage(error),
          onRetry: () => ref.invalidate(nearbyCourtsProvider),
        ),
        data: (courts) {
          if (courts.isEmpty) {
            return AppEmptyView(
              icon: Icons.sports_basketball_outlined,
              title: 'Aucun terrain à proximité',
              message:
                  "Aucun terrain n'a été trouvé dans un rayon de 5 km. "
                  'Vous pouvez en ajouter un vous-même.',
              actionLabel: 'Actualiser',
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
