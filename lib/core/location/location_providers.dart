import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_event.dart';
import '../analytics/analytics_providers.dart';
import '../analytics/app_events.dart';
import 'geolocator_location_service.dart';
import 'location_opt_in.dart';
import 'location_service.dart';

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((ref) => GeolocatorLocationService());

/// The user's current position, resolved once and shared by everything that
/// needs it.
///
/// Both the map (to centre itself) and the nearby-courts query need the same
/// position; reading it through one provider means one fix, one permission
/// prompt, and one cached answer rather than two competing ones.
///
/// It stays unresolved until the user has asked for it ([locationOptInProvider]):
/// this single gate is what keeps the system permission dialog off the first
/// screen of the app, whoever ends up needing a position first.
///
/// Auto-retry is disabled, like `nearbyCourtsProvider`: a denied permission
/// or a disabled GPS is not a transient failure, and retrying it in a loop
/// would re-prompt the user and drain the battery. Recovery is an explicit
/// refresh.
final FutureProvider<UserPosition> userPositionProvider =
    FutureProvider<UserPosition>((ref) async {
      if (!ref.watch(locationOptInProvider)) {
        throw const LocationNotRequestedException();
      }

      // The one place the system's answer becomes known, so the one place
      // that can count it. An opt-in that never turns into a position is the
      // app's worst outcome, and only this tells the three ways it happens
      // apart.
      final analytics = ref.watch(analyticsProvider);
      final service = ref.watch(locationServiceProvider);
      try {
        final position = await service.currentPosition();
        unawaited(
          analytics.log(AppEvents.locationOutcome(LocationOutcome.granted)),
        );
        return position;
      } catch (error) {
        unawaited(
          analytics.log(AppEvents.locationOutcome(locationOutcomeOf(error))),
        );
        rethrow;
      }
    }, retry: (retryCount, error) => null);

/// Which of the ways to have no position [error] is.
LocationOutcome locationOutcomeOf(Object error) => switch (error) {
  LocationPermissionPermanentlyDeniedException() =>
    LocationOutcome.deniedForever,
  LocationPermissionDeniedException() => LocationOutcome.denied,
  LocationServiceDisabledException() => LocationOutcome.serviceOff,
  LocationFixTimeoutException() => LocationOutcome.fixTimedOut,
  _ => LocationOutcome.notRequested,
};
