import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';

/// Several courts too close together to draw apart, shown as one disc with
/// the count on it.
///
/// Shaped like [CourtMarker] — same orange disc, same ring — because it is
/// the same thing seen from further away. What tells them apart is the
/// number in place of the ball, and a size that grows with the count so a
/// dense area reads as dense at a glance.
class CourtClusterMarker extends StatelessWidget {
  const CourtClusterMarker({super.key, required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  /// The box the marker is drawn in. Big enough for the largest disc plus
  /// its ring, so the map never clips a crowded cluster.
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Three steps rather than a continuous scale: the eye reads "more" from
    // a clear jump, not from two pixels of difference.
    final diameter = switch (count) {
      < 10 => 40.0,
      < 50 => 48.0,
      _ => 54.0,
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: AppStrings.courtClusterLabel(count),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: FittedBox(
                    child: Text(
                      '$count',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
