import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/location/location_opt_in_flow.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/location/location_service.dart';
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
    // Not having asked for a location yet is not a failure, and must not be
    // dressed as one: it is an offer, and the button is the whole point of
    // the screen.
    if (error is LocationNotRequestedException) {
      return AppEmptyView(
        icon: Icons.my_location,
        title: AppStrings.locationNotRequestedTitle,
        message: AppStrings.locationNotRequestedMessage,
        actionLabel: AppStrings.useMyLocation,
        actionIcon: Icons.my_location,
        onAction: () => requestLocationOptIn(context, ref),
        // Sharing a location is an offer, not a toll: there has to be a way
        // through this screen for someone who declines it.
        secondaryActionLabel: AppStrings.browseACity,
        onSecondaryAction: () => context.pushNamed(Routes.pickCityName),
      );
    }

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
