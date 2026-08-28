import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/location/location_service.dart';

/// Records which primitives [LocationService.currentPosition] calls, so the
/// orchestration can be asserted independently of any real plugin.
class _RecordingLocationService extends LocationService {
  _RecordingLocationService({
    this.serviceEnabled = true,
    this.initialPermission = LocationPermissionStatus.granted,
    this.permissionAfterRequest = LocationPermissionStatus.granted,
  });

  final bool serviceEnabled;
  final LocationPermissionStatus initialPermission;
  final LocationPermissionStatus permissionAfterRequest;

  int requestPermissionCallCount = 0;
  int readPositionCallCount = 0;

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
  Future<UserPosition> readPosition() async {
    readPositionCallCount++;
    return const UserPosition(latitude: 48.8566, longitude: 2.3522);
  }
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
      'does not prompt again when permission is permanently denied',
      () async {
        final service = _RecordingLocationService(
          initialPermission: LocationPermissionStatus.deniedForever,
        );

        await expectLater(
          service.currentPosition(),
          throwsA(isA<LocationPermissionDeniedException>()),
        );
        expect(service.requestPermissionCallCount, 0);
        expect(service.readPositionCallCount, 0);
      },
    );
  });
}
