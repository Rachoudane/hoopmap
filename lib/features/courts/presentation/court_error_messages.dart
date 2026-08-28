import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/location/location_service.dart';
import '../data/overpass_court_repository.dart';
import '../domain/court_repository.dart';

/// Translates the exceptions that can surface from the courts data layer
/// into a message a user can act on, so no screen ever shows a raw
/// exception type or message.
String courtErrorMessage(Object error) {
  if (error is LocationPermissionDeniedException) {
    return AppStrings.errorLocationPermissionDenied;
  }
  if (error is LocationServiceDisabledException) {
    return AppStrings.errorLocationServiceDisabled;
  }
  if (error is LocationFixTimeoutException) {
    return AppStrings.errorLocationTimeout;
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
  return Icons.wifi_off_rounded;
}
