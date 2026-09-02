import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';

class FakeLocationService extends LocationService {
  FakeLocationService.position(this._position) : _errorToThrow = null;
  FakeLocationService.throwing(this._errorToThrow) : _position = null;

  final UserPosition? _position;
  final Object? _errorToThrow;

  @override
  Future<bool> isServiceEnabled() async => true;

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

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) =>
      _controller.stream;

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

    test('a denied location permission surfaces as an error state', () async {
      // Broadcast controller: this test never listens to the stream (the
      // location error short-circuits before watchCourts() is reached), and
      // close() on an unlistened single-subscription controller never
      // completes, which would hang the teardown.
      final controller = StreamController<List<Court>>.broadcast();
      final container = ProviderContainer(
        overrides: [
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
  });
}
