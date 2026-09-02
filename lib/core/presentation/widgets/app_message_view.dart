import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_spacing.dart';

/// Full-body placeholder for an error state: an icon, a human-readable
/// message and, when [onRetry] is provided, a working "Retry" button.
///
/// [actionLabel]/[onAction] add a second, primary button above Retry, for the
/// errors retrying cannot fix on its own (a permission to re-grant in the
/// system settings, say). Retry stays available underneath it: coming back
/// from the settings is not the only way the situation can change.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.wifi_off_rounded,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.settings_outlined),
                label: Text(actionLabel!),
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(
                height: actionLabel != null && onAction != null
                    ? AppSpacing.md
                    : AppSpacing.xl,
              ),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-body placeholder for an empty-but-successful state: an icon, a
/// message and an optional useful action.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// A second way out, shown under the first — for the states where the
  /// obvious action isn't the only one (browsing a city rather than sharing
  /// a location, say).
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
