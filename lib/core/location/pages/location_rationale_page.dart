import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_strings.dart';
import '../../presentation/widgets/readable_width.dart';
import '../../theme/app_spacing.dart';

/// What the app is about to ask the system for, and why, before the system
/// asks it.
///
/// Android's dialog says one sentence, in the platform's words, with two
/// buttons: it cannot explain that the position never leaves the phone, that
/// it is only read while the app is open, or that saying no still leaves a
/// usable app. That explanation has to come first, from the app, on a screen
/// the user can leave without spending their one good answer — which is why
/// "Not now" pops without asking the system anything.
///
/// Pops `true` when the user allows, `false`/null otherwise, so the caller
/// (`requestLocationOptIn`) knows whether to opt in — and with it, let the
/// system ask.
class LocationRationalePage extends StatelessWidget {
  const LocationRationalePage({super.key});

  static const List<(IconData, String)> _reasons = <(IconData, String)>[
    (Icons.near_me_outlined, AppStrings.locationRationaleReasonDistance),
    (Icons.visibility_outlined, AppStrings.locationRationaleReasonWhileOpen),
    (Icons.lock_outline, AppStrings.locationRationaleReasonPrivate),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.my_location,
                            size: 44,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        AppStrings.locationRationaleTitle,
                        style: textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        AppStrings.locationRationaleIntro,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      for (final (icon, reason) in _reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, color: colorScheme.primary),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      // Says what happens next, so the system dialog arrives as
                      // the expected consequence of a button rather than as an
                      // interruption.
                      Text(
                        AppStrings.locationRationaleNextStep,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.pop(true),
                        child: const Text(AppStrings.locationRationaleAllow),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => context.pop(false),
                        child: const Text(AppStrings.locationRationaleNotNow),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
