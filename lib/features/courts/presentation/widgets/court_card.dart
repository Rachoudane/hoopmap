import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/court_with_distance.dart';
import '../../domain/distance.dart';
import 'court_pill.dart';

class CourtCard extends StatelessWidget {
  const CourtCard({super.key, required this.courtWithDistance, this.onTap});

  final CourtWithDistance courtWithDistance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final court = courtWithDistance.court;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sports_basketball,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        CourtPill(
                          icon: court.isOutdoor
                              ? Icons.wb_sunny_outlined
                              : Icons.home_work_outlined,
                          label: court.isOutdoor ? 'Extérieur' : 'Intérieur',
                        ),
                        CourtPill(
                          icon: Icons.sports_basketball_outlined,
                          label:
                              '${court.hoopCount} '
                              '${court.hoopCount > 1 ? 'paniers' : 'panier'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatDistanceLabel(courtWithDistance.distanceInMeters),
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
