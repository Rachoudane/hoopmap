import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/presentation/widgets/app_message_view.dart';
import '../../../../core/router/back_to_home_scope.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/court.dart';
import '../../domain/court_repository.dart';
import '../court_detail_provider.dart';
import '../court_error_messages.dart';
import '../widgets/court_photo.dart';
import '../widgets/court_pill.dart';

class CourtDetailPage extends ConsumerWidget {
  const CourtDetailPage({super.key, required this.courtId});

  final String courtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtAsync = ref.watch(courtDetailProvider(courtId));

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Détail du terrain')),
        body: courtAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            if (error is CourtNotFoundException) {
              return AppEmptyView(
                icon: Icons.search_off,
                title: 'Terrain introuvable',
                message: courtErrorMessage(error),
                actionLabel: 'Retour à la liste',
                onAction: () => context.go(Routes.home),
              );
            }
            return AppErrorView(
              message: courtErrorMessage(error),
              icon: courtErrorIcon(error),
              onRetry: () => ref.invalidate(courtDetailProvider(courtId)),
            );
          },
          data: (court) => _CourtDetailBody(court: court),
        ),
      ),
    );
  }
}

class _CourtDetailBody extends StatelessWidget {
  const _CourtDetailBody({required this.court});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isFromOpenStreetMap = court.id.startsWith('osm:');
    final source = isFromOpenStreetMap
        ? 'OpenStreetMap'
        : "Ajouté par un utilisateur de Hoopmap";

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (court.imageUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                0,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 200,
                child: CourtPhoto(
                  imageUrl: court.imageUrl,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  showAttribution: true,
                  fallback: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.14),
                    ),
                    child: Icon(
                      Icons.sports_basketball,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              court.imageUrl != null ? AppSpacing.lg : AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (court.imageUrl == null) ...[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sports_basketball,
                      size: 36,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(court.name, style: textTheme.displaySmall),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    CourtPill(
                      icon: court.isOutdoor
                          ? Icons.wb_sunny_outlined
                          : Icons.home_work_outlined,
                      label: court.isOutdoor
                          ? 'Terrain extérieur'
                          : 'Terrain intérieur',
                    ),
                    CourtPill(
                      icon: Icons.sports_basketball_outlined,
                      label:
                          '${court.hoopCount} '
                          '${court.hoopCount > 1 ? 'paniers' : 'panier'}',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Divider(color: colorScheme.outlineVariant),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${court.latitude.toStringAsFixed(5)}, '
                      '${court.longitude.toStringAsFixed(5)}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openDirections(court),
                    icon: const Icon(Icons.directions),
                    label: const Text('Itinéraire'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Source : $source',
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openDirections(Court court) async {
  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '${court.latitude},${court.longitude}',
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
