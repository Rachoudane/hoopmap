import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/location_providers.dart';
import '../../../../core/presentation/widgets/app_message_view.dart';
import '../court_error_messages.dart';

/// [AppErrorView] wired to a court error: the message and icon that match its
/// cause, a Retry button, and — for the failures the app cannot fix from
/// inside — the button that takes the user to the system screen that can.
///
/// Both the list and the map need that pairing; keeping it in one widget is
/// what stops a new recoverable error from being handled on one screen and
/// forgotten on the other.
class CourtErrorView extends ConsumerWidget {
  const CourtErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recovery = courtErrorRecovery(error);

    return AppErrorView(
      message: courtErrorMessage(error),
      icon: courtErrorIcon(error),
      onRetry: onRetry,
      actionLabel: recovery == null ? null : locationRecoveryLabel(recovery),
      actionIcon: recovery == null ? null : locationRecoveryIcon(recovery),
      onAction: recovery == null
          ? null
          : () => openLocationRecovery(
              ref.read(locationServiceProvider),
              recovery,
            ),
    );
  }
}
