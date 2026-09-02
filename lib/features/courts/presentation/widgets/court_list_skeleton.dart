import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/skeleton_box.dart';
import '../../../../core/theme/app_spacing.dart';

/// Loading placeholder shown while the first page of nearby courts is
/// fetched: shapes that mirror [CourtCard] instead of a bare spinner.
class CourtListSkeleton extends StatelessWidget {
  const CourtListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 6,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 48, height: 48, borderRadius: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(
                      width: MediaQuery.of(context).size.width * 0.45,
                      height: 16,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Wrap, not Row: the two pills are wider than a 320 dp
                    // phone leaves for them, and a placeholder overflowing
                    // is a stripe of yellow warning tape where the content
                    // is supposed to be.
                    const Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        SkeletonBox(width: 80, height: 22, borderRadius: 11),
                        SkeletonBox(width: 70, height: 22, borderRadius: 11),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const SkeletonBox(width: 36, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
