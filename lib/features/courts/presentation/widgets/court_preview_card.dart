import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/court_with_distance.dart';
import '../../domain/distance.dart';
import 'court_pill.dart';

/// Floating card shown above the map when a marker is tapped, with a way
/// to open the full court detail page.
class CourtPreviewCard extends StatelessWidget {
  const CourtPreviewCard({
    super.key,
    required this.courtWithDistance,
    required this.onOpenDetail,
    required this.onClose,
  });

  final CourtWithDistance courtWithDistance;
  final VoidCallback onOpenDetail;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final court = courtWithDistance.court;

    return Card(
      elevation: AppElevation.high,
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text(
                          formatDistanceLabel(
                            courtWithDistance.distanceInMeters,
                          ),
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        CourtPill(
                          icon: court.isOutdoor
                              ? Icons.wb_sunny_outlined
                              : Icons.home_work_outlined,
                          label: court.isOutdoor
                              ? AppStrings.outdoor
                              : AppStrings.indoor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                tooltip: AppStrings.close,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
