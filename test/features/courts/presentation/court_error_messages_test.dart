import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/features/courts/data/overpass_court_repository.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/presentation/court_error_messages.dart';

void main() {
  group('courtErrorMessage', () {
    test('gives a specific message for a denied location permission', () {
      expect(
        courtErrorMessage(const LocationPermissionDeniedException()),
        contains('Location access was denied'),
      );
    });

    test('tells a permanently denied permission apart from a refused one', () {
      expect(
        courtErrorMessage(const LocationPermissionPermanentlyDeniedException()),
        contains('app settings'),
      );
      // The recoverable denial must not send the user to the settings for a
      // permission the system will simply ask for again.
      expect(
        courtErrorMessage(const LocationPermissionDeniedException()),
        isNot(contains('app settings')),
      );
    });

    test('gives a specific message for a disabled location service', () {
      expect(
        courtErrorMessage(const LocationServiceDisabledException()),
        contains('turned off'),
      );
    });

    test('gives a specific message for a location fix that timed out', () {
      expect(
        courtErrorMessage(const LocationFixTimeoutException()),
        contains("Couldn't get your location in time"),
      );
    });

    test('gives a specific message for an Overpass rate limit', () {
      expect(
        courtErrorMessage(OverpassRateLimitedException()),
        contains('heavy load'),
      );
    });

    test('gives a specific message for an area that is too large', () {
      expect(
        courtErrorMessage(AreaTooLargeException(30)),
        contains('too large'),
      );
    });

    test('gives a specific message for a generic Overpass failure', () {
      expect(
        courtErrorMessage(OverpassException('boom')),
        contains('OpenStreetMap'),
      );
    });

    test('gives a specific message for a missing court', () {
      expect(
        courtErrorMessage(CourtNotFoundException('court-1')),
        contains("can't be found"),
      );
    });

    test('falls back to a generic message for an unrecognized error', () {
      expect(
        courtErrorMessage(Exception('anything else')),
        'Something went wrong. Try again.',
      );
    });
  });

  group('courtErrorIcon', () {
    test('uses a location icon for location-related errors', () {
      expect(
        courtErrorIcon(const LocationPermissionDeniedException()),
        Icons.location_off_rounded,
      );
      expect(
        courtErrorIcon(const LocationPermissionPermanentlyDeniedException()),
        Icons.location_off_rounded,
      );
      expect(
        courtErrorIcon(const LocationServiceDisabledException()),
        Icons.location_off_rounded,
      );
    });

    test('uses a searching icon, not location_off, for a timed-out fix', () {
      expect(
        courtErrorIcon(const LocationFixTimeoutException()),
        Icons.location_searching_rounded,
      );
    });

    test('uses a search icon for a missing court', () {
      expect(
        courtErrorIcon(CourtNotFoundException('court-1')),
        Icons.search_off,
      );
    });

    test('falls back to a network icon for everything else', () {
      expect(courtErrorIcon(OverpassException('boom')), Icons.wifi_off_rounded);
      expect(
        courtErrorIcon(Exception('anything else')),
        Icons.wifi_off_rounded,
      );
    });
  });

  group('courtErrorRecovery', () {
    test('sends a permanently denied permission to the app settings', () {
      expect(
        courtErrorRecovery(
          const LocationPermissionPermanentlyDeniedException(),
        ),
        LocationRecovery.appSettings,
      );
    });

    test('sends a disabled location service to the location settings', () {
      expect(
        courtErrorRecovery(const LocationServiceDisabledException()),
        LocationRecovery.locationSettings,
      );
    });

    test('offers nothing for a denial the system can still prompt for', () {
      expect(
        courtErrorRecovery(const LocationPermissionDeniedException()),
        isNull,
      );
    });

    test('offers nothing for the failures retrying can fix', () {
      expect(courtErrorRecovery(const LocationFixTimeoutException()), isNull);
      expect(courtErrorRecovery(OverpassException('boom')), isNull);
      expect(courtErrorRecovery(OverpassRateLimitedException()), isNull);
      expect(courtErrorRecovery(Exception('anything else')), isNull);
    });

    test('labels each recovery with the screen it opens', () {
      expect(
        locationRecoveryLabel(LocationRecovery.appSettings),
        'Open settings',
      );
      expect(
        locationRecoveryLabel(LocationRecovery.locationSettings),
        'Turn on location',
      );
    });
  });

  group('openLocationRecovery', () {
    test('opens the app settings, and nothing else, for appSettings', () async {
      final service = _RecordingLocationService();

      await openLocationRecovery(service, LocationRecovery.appSettings);

      expect(service.openAppSettingsCallCount, 1);
      expect(service.openLocationSettingsCallCount, 0);
    });

    test('opens the location settings for locationSettings', () async {
      final service = _RecordingLocationService();

      await openLocationRecovery(service, LocationRecovery.locationSettings);

      expect(service.openLocationSettingsCallCount, 1);
      expect(service.openAppSettingsCallCount, 0);
    });
  });
}

/// Counts which system screen was opened, so the mapping from a recovery to
/// a settings screen is asserted rather than assumed.
class _RecordingLocationService extends LocationService {
  int openAppSettingsCallCount = 0;
  int openLocationSettingsCallCount = 0;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCallCount++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCallCount++;
    return true;
  }

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<UserPosition> readPosition() async =>
      const UserPosition(latitude: 0, longitude: 0);

  @override
  Future<UserPosition?> lastKnownPosition() async => null;
}
