import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/skeleton_box.dart';
import '../../../../core/theme/app_spacing.dart';

/// Loading placeholder for a court's detail page: the shape of the page that
/// is coming, not a spinner in the middle of an empty screen.
///
/// A spinner says "wait"; this says what the wait is for. It matters most
/// here, because a court detail page can be opened cold from a deep link,
/// where the spinner would be the user's first impression of the app.
class CourtDetailSkeleton extends StatelessWidget {
  const CourtDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        SkeletonBox(width: double.infinity, height: 180, borderRadius: 12),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(width: 220, height: 26),
        SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SkeletonBox(width: 96, height: 24, borderRadius: 12),
            SkeletonBox(width: 84, height: 24, borderRadius: 12),
          ],
        ),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(width: 180, height: 16),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(width: double.infinity, height: 48, borderRadius: 12),
      ],
    );
  }
}
