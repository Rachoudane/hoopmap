import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_providers.dart';
import '../../../../core/analytics/app_events.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/presentation/widgets/app_message_view.dart';
import '../../../../core/router/back_to_home_scope.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../reports/presentation/widgets/report_court_dialog.dart';
import '../../domain/court.dart';
import '../../domain/court_repository.dart';
import '../court_detail_provider.dart';
import '../court_error_messages.dart';
import '../widgets/court_detail_skeleton.dart';
import '../widgets/court_error_view.dart';
import '../widgets/court_photo.dart';
import '../widgets/court_pill.dart';

class CourtDetailPage extends ConsumerStatefulWidget {
  const CourtDetailPage({super.key, required this.courtId});

  final String courtId;

  @override
  ConsumerState<CourtDetailPage> createState() => _CourtDetailPageState();
}

class _CourtDetailPageState extends ConsumerState<CourtDetailPage> {
  @override
  void initState() {
    super.initState();
    // Here rather than at the taps that lead here: a cold deep link opens
    // this page with no tap of its own, and a court-opened count that
    // silently omits them measures the wrong app.
    unawaited(
      ref
          .read(analyticsProvider)
          .log(AppEvents.courtOpened(courtOriginOf(widget.courtId))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courtId = widget.courtId;
    final courtAsync = ref.watch(courtDetailProvider(courtId));

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.courtDetailTitle)),
        body: courtAsync.when(
          loading: () => const CourtDetailSkeleton(),
          error: (error, stackTrace) {
            if (error is CourtNotFoundException) {
              return AppEmptyView(
                icon: Icons.search_off,
                title: AppStrings.courtNotFoundTitle,
                message: courtErrorMessage(error),
                actionLabel: AppStrings.backToList,
                onAction: () => context.go(Routes.home),
              );
            }
            // The same error view as the list and the map: one place
            // decides what an error looks like and what it offers.
            return CourtErrorView(
              error: error,
              onRetry: () => ref.invalidate(courtDetailProvider(courtId)),
            );
          },
          data: (court) => _CourtDetailBody(court: court),
        ),
      ),
    );
  }
}

/// Whether [courtId] names a court imported from OpenStreetMap or one added
/// here, which is the one thing about a court known before it has loaded.
CourtOrigin courtOriginOf(String courtId) => courtId.startsWith('osm:')
    ? CourtOrigin.openStreetMap
    : CourtOrigin.hoopmap;

class _CourtDetailBody extends ConsumerWidget {
  const _CourtDetailBody({required this.court});

  final Court court;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isFromOpenStreetMap = court.id.startsWith('osm:');
    final source = isFromOpenStreetMap
        ? 'OpenStreetMap'
        : AppStrings.addedByHoopmapUser;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
                            ? AppStrings.outdoorCourt
                            : AppStrings.indoorCourt,
                      ),
                      CourtPill(
                        icon: Icons.sports_basketball_outlined,
                        label: AppStrings.hoopCount(court.hoopCount),
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
                      // Expanded, because a pair of five-decimal coordinates
                      // at the system's largest text setting is wider than a
                      // small phone.
                      Expanded(
                        child: Text(
                          '${court.latitude.toStringAsFixed(5)}, '
                          '${court.longitude.toStringAsFixed(5)}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // The end of the loop the app exists for: someone
                        // is leaving to go and play.
                        unawaited(
                          ref
                              .read(analyticsProvider)
                              .log(
                                AppEvents.directionsOpened(
                                  courtOriginOf(court.id),
                                ),
                              ),
                        );
                        _openDirections(court);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text(AppStrings.directions),
                    ),
                  ),
                  if (!isFromOpenStreetMap) ...[
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            showReportCourtDialog(context, court.id),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text(AppStrings.reportThisCourt),
                      ),
                    ),
                  ],
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
                          AppStrings.source(source),
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
