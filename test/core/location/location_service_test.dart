import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/location/location_service.dart';

/// Records which primitives [LocationService.currentPosition] calls, so the
/// orchestration can be asserted independently of any real plugin.
class _RecordingLocationService extends LocationService {
  _RecordingLocationService({
    this.serviceEnabled = true,
    this.initialPermission = LocationPermissionStatus.granted,
    this.permissionAfterRequest = LocationPermissionStatus.granted,
    this.fixNeverArrives = false,
    this.lastKnown,
  });

  final bool serviceEnabled;
  final LocationPermissionStatus initialPermission;
  final LocationPermissionStatus permissionAfterRequest;

  /// Makes [readPosition] hang forever, the way a cold GPS start indoors does.
  final bool fixNeverArrives;
  final UserPosition? lastKnown;

  int requestPermissionCallCount = 0;
  int readPositionCallCount = 0;
  int lastKnownPositionCallCount = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => initialPermission;

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestPermissionCallCount++;
    return permissionAfterRequest;
  }

  @override
  Future<UserPosition> readPosition() {
    readPositionCallCount++;
    if (fixNeverArrives) return Completer<UserPosition>().future;
    return Future.value(
      const UserPosition(latitude: 48.8566, longitude: 2.3522),
    );
  }

  @override
  Future<UserPosition?> lastKnownPosition() async {
    lastKnownPositionCallCount++;
    return lastKnown;
  }

  // Never reached by currentPosition(); the screens that offer them are
  // where they are asserted.
  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  group('LocationService.currentPosition', () {
    test('returns the position when services are on and permission is '
        'already granted, without prompting', () async {
      final service = _RecordingLocationService();

      final position = await service.currentPosition();

      expect(
        position,
        const UserPosition(latitude: 48.8566, longitude: 2.3522),
      );
      expect(service.requestPermissionCallCount, 0);
    });

    test('throws LocationServiceDisabledException and never reads a position '
        'when location services are off', () async {
      final service = _RecordingLocationService(serviceEnabled: false);

      await expectLater(
        service.currentPosition(),
        throwsA(isA<LocationServiceDisabledException>()),
      );
      expect(service.requestPermissionCallCount, 0);
      expect(service.readPositionCallCount, 0);
    });

    test('prompts once when permission is denied, then reads the position '
        'if it is granted', () async {
      final service = _RecordingLocationService(
        initialPermission: LocationPermissionStatus.denied,
        permissionAfterRequest: LocationPermissionStatus.granted,
      );

      await service.currentPosition();

      expect(service.requestPermissionCallCount, 1);
      expect(service.readPositionCallCount, 1);
    });

    test('throws LocationPermissionDeniedException when the prompt is '
        'refused', () async {
      final service = _RecordingLocationService(
        initialPermission: LocationPermissionStatus.denied,
        permissionAfterRequest: LocationPermissionStatus.denied,
      );

      await expectLater(
        service.currentPosition(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
      expect(service.requestPermissionCallCount, 1);
      expect(service.readPositionCallCount, 0);
    });

    test(
      'does not prompt again when permission is permanently denied, and says '
      'so with its own exception',
      () async {
        final service = _RecordingLocationService(
          initialPermission: LocationPermissionStatus.deniedForever,
        );

        await expectLater(
          service.currentPosition(),
          throwsA(isA<LocationPermissionPermanentlyDeniedException>()),
        );
        expect(service.requestPermissionCallCount, 0);
        expect(service.readPositionCallCount, 0);
      },
    );

    test('a prompt answered with "never ask again" is permanent, not a plain '
        'refusal', () async {
      // The distinction the UI hangs on: this user has no prompt left to
      // accept, so the only honest button is the one to the settings.
      final service = _RecordingLocationService(
        initialPermission: LocationPermissionStatus.denied,
        permissionAfterRequest: LocationPermissionStatus.deniedForever,
      );

      await expectLater(
        service.currentPosition(),
        throwsA(isA<LocationPermissionPermanentlyDeniedException>()),
      );
      expect(service.requestPermissionCallCount, 1);
      expect(service.readPositionCallCount, 0);
    });

    test('a refused prompt is not reported as permanent', () async {
      final service = _RecordingLocationService(
        initialPermission: LocationPermissionStatus.denied,
        permissionAfterRequest: LocationPermissionStatus.denied,
      );

      await expectLater(
        service.currentPosition(),
        throwsA(isNot(isA<LocationPermissionPermanentlyDeniedException>())),
      );
    });

    test(
      'falls back to the last known position when the fix times out',
      () async {
        final service = _RecordingLocationService(
          fixNeverArrives: true,
          lastKnown: const UserPosition(latitude: 45.7640, longitude: 4.8357),
        );

        final position = await service.currentPosition(
          timeout: const Duration(milliseconds: 20),
        );

        expect(
          position,
          const UserPosition(latitude: 45.7640, longitude: 4.8357),
        );
        expect(service.lastKnownPositionCallCount, 1);
      },
    );

    test('throws LocationFixTimeoutException when the fix times out and there '
        'is no last known position', () async {
      final service = _RecordingLocationService(fixNeverArrives: true);

      await expectLater(
        service.currentPosition(timeout: const Duration(milliseconds: 20)),
        throwsA(isA<LocationFixTimeoutException>()),
      );
      expect(service.lastKnownPositionCallCount, 1);
    });

    test(
      'never asks for the last known position when the fix arrives in time',
      () async {
        final service = _RecordingLocationService(
          lastKnown: const UserPosition(latitude: 45.7640, longitude: 4.8357),
        );

        final position = await service.currentPosition();

        expect(
          position,
          const UserPosition(latitude: 48.8566, longitude: 2.3522),
        );
        expect(service.lastKnownPositionCallCount, 0);
      },
    );
  });
}
