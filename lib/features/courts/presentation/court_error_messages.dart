import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/location/location_service.dart';
import '../data/overpass_court_repository.dart';
import '../domain/court_repository.dart';

/// Translates the exceptions that can surface from the courts data layer
/// into a message a user can act on, so no screen ever shows a raw
/// exception type or message.
String courtErrorMessage(Object error) {
  if (error is LocationPermissionPermanentlyDeniedException) {
    return AppStrings.errorLocationPermissionPermanentlyDenied;
  }
  if (error is LocationPermissionDeniedException) {
    return AppStrings.errorLocationPermissionDenied;
  }
  if (error is LocationServiceDisabledException) {
    return AppStrings.errorLocationServiceDisabled;
  }
  if (error is LocationFixTimeoutException) {
    return AppStrings.errorLocationTimeout;
  }
  if (error is NetworkUnavailableException) {
    return AppStrings.errorOffline;
  }
  if (error is OverpassRateLimitedException) {
    return AppStrings.errorOverpassRateLimited;
  }
  if (error is AreaTooLargeException) {
    return AppStrings.errorAreaTooLarge;
  }
  if (error is OverpassException) {
    return AppStrings.errorOverpass;
  }
  if (error is CourtNotFoundException) {
    return AppStrings.errorCourtNotFound;
  }
  return AppStrings.errorUnexpected;
}

/// An icon matching [courtErrorMessage]'s cause, so a location-permission
/// error doesn't show a network icon (or vice versa).
IconData courtErrorIcon(Object error) {
  if (error is LocationPermissionDeniedException ||
      error is LocationPermissionPermanentlyDeniedException ||
      error is LocationServiceDisabledException) {
    return Icons.location_off_rounded;
  }
  // Not location_off: the fix was allowed and attempted, it just never
  // arrived, so the icon shouldn't read as "location is switched off".
  if (error is LocationFixTimeoutException) {
    return Icons.location_searching_rounded;
  }
  if (error is CourtNotFoundException) {
    return Icons.search_off;
  }
  // The service and the connection get different icons for the same reason
  // they get different messages: one is something to wait out, the other is
  // something to go and fix.
  if (error is NetworkUnavailableException) {
    return Icons.wifi_off_rounded;
  }
  if (error is OverpassException || error is OverpassRateLimitedException) {
    return Icons.cloud_off_rounded;
  }
  return Icons.wifi_off_rounded;
}

/// The way out of an error the app itself cannot fix, because the setting
/// that blocks it lives outside the app.
enum LocationRecovery {
  /// The permission has to be granted again from the app's settings page.
  appSettings,

  /// Location services have to be switched back on, device-wide.
  locationSettings,
}

/// The system screen that can unblock [error], or null when retrying inside
/// the app is all it takes.
///
/// A plain [LocationPermissionDeniedException] deliberately maps to null: the
/// system will prompt again, so Retry is the honest button — sending the user
/// to the settings for a permission they can simply be asked for is a longer
/// road to the same place.
LocationRecovery? courtErrorRecovery(Object error) {
  if (error is LocationPermissionPermanentlyDeniedException) {
    return LocationRecovery.appSettings;
  }
  if (error is LocationServiceDisabledException) {
    return LocationRecovery.locationSettings;
  }
  return null;
}

String locationRecoveryLabel(LocationRecovery recovery) => switch (recovery) {
  LocationRecovery.appSettings => AppStrings.openAppSettings,
  LocationRecovery.locationSettings => AppStrings.openLocationSettings,
};

IconData locationRecoveryIcon(LocationRecovery recovery) => switch (recovery) {
  LocationRecovery.appSettings => Icons.settings_outlined,
  LocationRecovery.locationSettings => Icons.location_on_outlined,
};

/// Opens the system screen [recovery] points at.
///
/// Nothing is done with the result on purpose: whether the settings screen
/// opened or not, what matters next is the state the user comes back with,
/// which [LocationResumeRefresher] picks up on resume.
Future<void> openLocationRecovery(
  LocationService service,
  LocationRecovery recovery,
) async {
  switch (recovery) {
    case LocationRecovery.appSettings:
      await service.openAppSettings();
    case LocationRecovery.locationSettings:
      await service.openLocationSettings();
  }
}
