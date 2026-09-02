import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/location/location_opt_in.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/settings/settings_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:hoopmap/features/courts/presentation/browse_city_provider.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';

/// A user browsing from their own position: they asked for their location,
/// and picked no city to browse instead. Both gates have their own tests;
/// these start where a user who pressed "See courts near me" starts.
final _fromTheUsersOwnPosition = [
  locationOptInProvider.overrideWithBuild((ref, notifier) => true),
  browseCityProvider.overrideWithBuild((ref, notifier) => null),
  // The shipped radius: these tests are about what the search does with an
  // area, not about which one the user picked.
  searchRadiusProvider.overrideWithBuild(
    (ref, notifier) => defaultSearchRadiusInMeters,
  ),
];

class FakeLocationService extends LocationService {
  FakeLocationService.position(this._position) : _errorToThrow = null;
  FakeLocationService.throwing(this._errorToThrow) : _position = null;

  final UserPosition? _position;
  final Object? _errorToThrow;

  @override
  Future<bool> isServiceEnabled() async {
    // The service check comes first in currentPosition(), so a fake that only
    // throws from readPosition() could never reproduce a disabled-GPS
    // failure. Throwing here keeps the failure the test asked for intact.
    final error = _errorToThrow;
    if (error != null) throw error;
    return true;
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<UserPosition> readPosition() async {
    final error = _errorToThrow;
    if (error != null) throw error;
    return _position!;
  }

  @override
  Future<UserPosition?> lastKnownPosition() async => null;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class FakeCourtRepository implements CourtRepository {
  FakeCourtRepository(this._controller);

  final StreamController<List<Court>> _controller;
  final List<GeoBounds> requestedBounds = [];

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) {
    requestedBounds.add(bounds);
    return _controller.stream;
  }

  @override
  Stream<Court> watchCourt(String id) => Stream.error(UnimplementedError());

  @override
  Future<String> addCourt(Court court) => throw UnimplementedError();
}

Court _court(String id, double latitude, double longitude) => Court(
  id: id,
  name: id,
  latitude: latitude,
  longitude: longitude,
  hoopCount: 1,
  isOutdoor: true,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('NearbyCourtsNotifier', () {
    test('sorts courts by distance ascending from the user position', () async {
      final controller = StreamController<List<Court>>();
      final container = ProviderContainer(
        overrides: [
          ..._fromTheUsersOwnPosition,
          locationServiceProvider.overrideWithValue(
            FakeLocationService.position(
              const UserPosition(latitude: 0, longitude: 0),
            ),
          ),
          courtRepositoryProvider.overrideWithValue(
            FakeCourtRepository(controller),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(controller.close);
      container.listen(nearbyCourtsProvider, (previous, next) {});

      final far = _court('far', 1, 0);
      final near = _court('near', 0.01, 0);
      final mid = _court('mid', 0.1, 0);

      final future = container.read(nearbyCourtsProvider.future);
      controller.add([far, near, mid]);
      final result = await future;

      expect(result.map((c) => c.court.id).toList(), ['near', 'mid', 'far']);
      expect(result[0].distanceInMeters, lessThan(result[1].distanceInMeters));
      expect(result[1].distanceInMeters, lessThan(result[2].distanceInMeters));
    });

    test('an empty collection yields an empty list', () async {
      final controller = StreamController<List<Court>>();
      final container = ProviderContainer(
        overrides: [
          ..._fromTheUsersOwnPosition,
          locationServiceProvider.overrideWithValue(
            FakeLocationService.position(
              const UserPosition(latitude: 0, longitude: 0),
            ),
          ),
          courtRepositoryProvider.overrideWithValue(
            FakeCourtRepository(controller),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(controller.close);
      container.listen(nearbyCourtsProvider, (previous, next) {});

      final future = container.read(nearbyCourtsProvider.future);
      controller.add(const []);
      final result = await future;

      expect(result, isEmpty);
    });

    test('every location failure surfaces as its own error state, so each '
        'screen can offer the right way out', () async {
      for (final failure in const [
        LocationPermissionDeniedException(),
        LocationPermissionPermanentlyDeniedException(),
        LocationServiceDisabledException(),
        LocationFixTimeoutException(),
      ]) {
        // Broadcast, for the same reason as the test below: the location
        // failure short-circuits before anything listens to the stream.
        final controller = StreamController<List<Court>>.broadcast();
        final container = ProviderContainer(
          overrides: [
            ..._fromTheUsersOwnPosition,
            locationServiceProvider.overrideWithValue(
              FakeLocationService.throwing(failure),
            ),
            courtRepositoryProvider.overrideWithValue(
              FakeCourtRepository(controller),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(controller.close);
        container.listen(nearbyCourtsProvider, (previous, next) {});

        await expectLater(
          container.read(nearbyCourtsProvider.future),
          throwsA(same(failure)),
          reason: 'the search must not repackage $failure',
        );
      }
    });

    test('a location failure never reaches the repository', () async {
      final controller = StreamController<List<Court>>.broadcast();
      final repository = FakeCourtRepository(controller);
      final container = ProviderContainer(
        overrides: [
          ..._fromTheUsersOwnPosition,
          locationServiceProvider.overrideWithValue(
            FakeLocationService.throwing(
              const LocationServiceDisabledException(),
            ),
          ),
          courtRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(controller.close);
      container.listen(nearbyCourtsProvider, (previous, next) {});

      await expectLater(
        container.read(nearbyCourtsProvider.future),
        throwsA(isA<LocationServiceDisabledException>()),
      );
      // No position, no box to search: querying Overpass anyway would spend a
      // request on a place picked at random.
      expect(controller.hasListener, isFalse);
    });

    test('a denied location permission surfaces as an error state', () async {
      // Broadcast controller: this test never listens to the stream (the
      // location error short-circuits before watchCourts() is reached), and
      // close() on an unlistened single-subscription controller never
      // completes, which would hang the teardown.
      final controller = StreamController<List<Court>>.broadcast();
      final container = ProviderContainer(
        overrides: [
          ..._fromTheUsersOwnPosition,
          locationServiceProvider.overrideWithValue(
            FakeLocationService.throwing(
              const LocationPermissionDeniedException(),
            ),
          ),
          courtRepositoryProvider.overrideWithValue(
            FakeCourtRepository(controller),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(controller.close);
      container.listen(nearbyCourtsProvider, (previous, next) {});

      await expectLater(
        container.read(nearbyCourtsProvider.future),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    });

    test('a new repository emission produces a new sorted list', () async {
      final controller = StreamController<List<Court>>();
      final container = ProviderContainer(
        overrides: [
          ..._fromTheUsersOwnPosition,
          locationServiceProvider.overrideWithValue(
            FakeLocationService.position(
              const UserPosition(latitude: 0, longitude: 0),
            ),
          ),
          courtRepositoryProvider.overrideWithValue(
            FakeCourtRepository(controller),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(controller.close);

      final emissions = <List<CourtWithDistance>>[];
      final firstEmission = Completer<void>();
      final secondEmission = Completer<void>();
      container.listen(nearbyCourtsProvider, (previous, next) {
        final value = next.value;
        if (value == null) return;
        emissions.add(value);
        if (emissions.length == 1) firstEmission.complete();
        if (emissions.length == 2) secondEmission.complete();
      }, fireImmediately: true);

      controller.add([_court('a', 0.02, 0), _court('b', 0.01, 0)]);
      await firstEmission.future;
      expect(emissions[0].map((c) => c.court.id).toList(), ['b', 'a']);

      controller.add([_court('c', 0.005, 0), _court('a', 0.02, 0)]);
      await secondEmission.future;
      expect(emissions[1].map((c) => c.court.id).toList(), ['c', 'a']);
    });

    test('the searched area follows the radius the user picked', () async {
      // Single-subscription, so the emission waits for the notifier to
      // subscribe rather than being dropped before it does.
      final controller = StreamController<List<Court>>();
      final repository = FakeCourtRepository(controller);
      final container = ProviderContainer(
        overrides: [
          locationOptInProvider.overrideWithBuild((ref, notifier) => true),
          browseCityProvider.overrideWithBuild((ref, notifier) => null),
          searchRadiusProvider.overrideWithBuild((ref, notifier) => 20000),
          locationServiceProvider.overrideWithValue(
            FakeLocationService.position(
              const UserPosition(latitude: 0, longitude: 0),
            ),
          ),
          courtRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(controller.close);
      container.listen(nearbyCourtsProvider, (previous, next) {});

      final future = container.read(nearbyCourtsProvider.future);
      controller.add(const []);
      await future;

      // 20 km either side of the equator, in degrees of latitude.
      final bounds = repository.requestedBounds.single;
      expect(bounds.maxLat - bounds.minLat, closeTo(0.36, 0.01));
    });
  });
}
