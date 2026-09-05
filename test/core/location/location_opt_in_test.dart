import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoopmap/core/analytics/analytics_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/location/location_opt_in.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts every way this service could reach the device's location, so a
/// test can assert that none of them happened.
class _CountingLocationService extends LocationService {
  int isServiceEnabledCallCount = 0;
  int checkPermissionCallCount = 0;
  int requestPermissionCallCount = 0;
  int readPositionCallCount = 0;

  int get deviceCallCount =>
      isServiceEnabledCallCount +
      checkPermissionCallCount +
      requestPermissionCallCount +
      readPositionCallCount;

  @override
  Future<bool> isServiceEnabled() async {
    isServiceEnabledCallCount++;
    return true;
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    checkPermissionCallCount++;
    return LocationPermissionStatus.granted;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    requestPermissionCallCount++;
    return LocationPermissionStatus.granted;
  }

  @override
  Future<UserPosition> readPosition() async {
    readPositionCallCount++;
    return const UserPosition(latitude: 48.8566, longitude: 2.3522);
  }

  @override
  Future<UserPosition?> lastKnownPosition() async => null;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

Future<ProviderContainer> _container({
  Map<String, Object> initialPreferences = const {},
  LocationService? locationService,
}) async {
  SharedPreferences.setMockInitialValues(initialPreferences);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      if (locationService != null)
        locationServiceProvider.overrideWithValue(locationService),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('locationOptInProvider', () {
    test('starts false: the app has asked for nothing yet', () async {
      final container = await _container();

      expect(container.read(locationOptInProvider), isFalse);
    });

    test('reflects a previously persisted opt-in', () async {
      final container = await _container(
        initialPreferences: {'location_opt_in': true},
      );

      expect(container.read(locationOptInProvider), isTrue);
    });

    test('optIn() flips the state and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);

      await container
          .read(locationOptInProvider.notifier)
          .optIn(LocationEntryPoint.onboarding);

      expect(container.read(locationOptInProvider), isTrue);
      // "I already asked for this" has to survive a restart, or the app
      // would go back to asking on every launch.
      expect(preferences.getBool('location_opt_in'), isTrue);
    });
  });

  group('userPositionProvider', () {
    test('never touches the device before the user has asked', () async {
      final service = _CountingLocationService();
      final container = await _container(locationService: service);

      await expectLater(
        container.read(userPositionProvider.future),
        throwsA(isA<LocationNotRequestedException>()),
      );
      // Not even a permission check: on Android, checkPermission is silent
      // but requestPermission is the dialog, and the gate has to sit in
      // front of the whole sequence rather than partway through it.
      expect(service.deviceCallCount, 0);
    });

    test('takes a fix as soon as the user asks for one', () async {
      final service = _CountingLocationService();
      final container = await _container(locationService: service);
      container.listen(userPositionProvider, (previous, next) {});

      await expectLater(
        container.read(userPositionProvider.future),
        throwsA(isA<LocationNotRequestedException>()),
      );

      await container
          .read(locationOptInProvider.notifier)
          .optIn(LocationEntryPoint.inApp);

      expect(
        await container.read(userPositionProvider.future),
        const UserPosition(latitude: 48.8566, longitude: 2.3522),
      );
      expect(service.readPositionCallCount, 1);
    });

    test(
      'a user who opted in on a previous launch is not asked again',
      () async {
        final service = _CountingLocationService();
        final container = await _container(
          initialPreferences: {'location_opt_in': true},
          locationService: service,
        );

        expect(
          await container.read(userPositionProvider.future),
          const UserPosition(latitude: 48.8566, longitude: 2.3522),
        );
      },
    );
  });
}
