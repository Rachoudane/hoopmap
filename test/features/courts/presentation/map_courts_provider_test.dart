import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:hoopmap/features/courts/presentation/map_courts_provider.dart';

class _FakeCourtRepository implements CourtRepository {
  _FakeCourtRepository(this.courts, {this.error});

  final List<Court> courts;
  final Object? error;
  final List<GeoBounds> requestedBounds = [];

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) async* {
    requestedBounds.add(bounds);
    final failure = error;
    if (failure != null) throw failure;
    yield courts;
  }

  @override
  Stream<Court> watchCourt(String id) => Stream.error(UnimplementedError());

  @override
  Future<String> addCourt(Court court) => throw UnimplementedError();
}

class _FakeLocationService extends LocationService {
  _FakeLocationService({this.position, this.error});

  final UserPosition? position;
  final Object? error;

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
    final failure = error;
    if (failure != null) throw failure;
    return position!;
  }

  @override
  Future<UserPosition?> lastKnownPosition() async => null;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
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

/// A box roughly a degree across, centred on ([latitude], [longitude]).
GeoBounds _boxAround(double latitude, double longitude) => GeoBounds(
  minLat: latitude - 0.5,
  maxLat: latitude + 0.5,
  minLng: longitude - 0.5,
  maxLng: longitude + 0.5,
);

/// Reads a bounds search while holding it open.
///
/// The provider disposes as soon as nothing watches it — which is what keeps
/// panned-away viewports from piling up — so a test has to hold the
/// subscription the map page holds.
Future<List<CourtWithDistance>> _searchCourts(
  ProviderContainer container,
  GeoBounds bounds,
) {
  final subscription = container.listen(
    courtsInBoundsProvider(bounds),
    (previous, next) {},
  );
  addTearDown(subscription.close);
  return container.read(courtsInBoundsProvider(bounds).future);
}

ProviderContainer _containerWith({
  required CourtRepository repository,
  required LocationService locationService,
}) {
  final container = ProviderContainer(
    overrides: [
      courtRepositoryProvider.overrideWithValue(repository),
      locationServiceProvider.overrideWithValue(locationService),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('visibleMapBoundsProvider', () {
    test('starts empty, so the map opens on the courts around the user', () {
      final container = _containerWith(
        repository: _FakeCourtRepository(const []),
        locationService: _FakeLocationService(
          position: const UserPosition(latitude: 0, longitude: 0),
        ),
      );

      expect(container.read(visibleMapBoundsProvider), isNull);
    });

    test('takes the viewport, and gives it back on clear()', () {
      final container = _containerWith(
        repository: _FakeCourtRepository(const []),
        locationService: _FakeLocationService(
          position: const UserPosition(latitude: 0, longitude: 0),
        ),
      );
      final bounds = _boxAround(45, 5);

      container.read(visibleMapBoundsProvider.notifier).bounds = bounds;
      expect(container.read(visibleMapBoundsProvider), bounds);

      container.read(visibleMapBoundsProvider.notifier).clear();
      expect(container.read(visibleMapBoundsProvider), isNull);
    });
  });

  group('courtsInBoundsProvider', () {
    test('searches exactly the box it was asked for', () async {
      final repository = _FakeCourtRepository([_court('a', 45, 5)]);
      final container = _containerWith(
        repository: repository,
        locationService: _FakeLocationService(
          position: const UserPosition(latitude: 48.8566, longitude: 2.3522),
        ),
      );
      final bounds = _boxAround(45, 5);

      await _searchCourts(container, bounds);

      expect(repository.requestedBounds, [bounds]);
    });

    test(
      'measures distances from the user when their position is known',
      () async {
        final repository = _FakeCourtRepository([
          _court('far-from-user', 45.4, 5),
          _court('near-user', 45.05, 5),
        ]);
        final container = _containerWith(
          repository: repository,
          locationService: _FakeLocationService(
            position: const UserPosition(latitude: 45, longitude: 5),
          ),
        );
        // The user sits at the southern edge of the box they are looking at,
        // so ordering by distance from them is not the same as ordering by
        // distance from its middle.
        final courts = await _searchCourts(container, _boxAround(45.2, 5));

        expect(courts.map((c) => c.court.id).toList(), [
          'near-user',
          'far-from-user',
        ]);
      },
    );

    test(
      'falls back to the middle of the viewport when there is no position',
      () async {
        final repository = _FakeCourtRepository([
          _court('edge', 45.45, 5),
          _court('middle', 45.2, 5),
        ]);
        final container = _containerWith(
          repository: repository,
          locationService: _FakeLocationService(
            error: const LocationPermissionPermanentlyDeniedException(),
          ),
        );

        // Courts still get a distance, and the nearest to what the user is
        // looking at comes first.
        final courts = await _searchCourts(container, _boxAround(45.2, 5));

        expect(courts.map((c) => c.court.id).toList(), ['middle', 'edge']);
        expect(courts.first.distanceInMeters, lessThan(1000));
      },
    );

    test('answers a box it already searched without querying again', () async {
      final repository = _FakeCourtRepository([_court('a', 45, 5)]);
      final container = _containerWith(
        repository: repository,
        locationService: _FakeLocationService(
          position: const UserPosition(latitude: 45, longitude: 5),
        ),
      );
      final bounds = _boxAround(45, 5);

      await _searchCourts(container, bounds);
      // The same box, rebuilt from a viewport that came back to it.
      await _searchCourts(container, _boxAround(45, 5));

      expect(repository.requestedBounds, hasLength(1));
    });

    test('surfaces a repository failure as an error state', () async {
      final container = _containerWith(
        repository: _FakeCourtRepository(
          const [],
          error: StateError('overpass is down'),
        ),
        locationService: _FakeLocationService(
          position: const UserPosition(latitude: 45, longitude: 5),
        ),
      );

      await expectLater(
        _searchCourts(container, _boxAround(45, 5)),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'a location failure does not stop the map from searching a box',
      () async {
        final repository = _FakeCourtRepository([_court('a', 45, 5)]);
        final container = _containerWith(
          repository: repository,
          locationService: _FakeLocationService(
            error: const LocationServiceDisabledException(),
          ),
        );

        // The whole point of panning: exploring somewhere else must not depend
        // on knowing where the user is.
        final courts = await _searchCourts(container, _boxAround(45, 5));

        expect(courts.map((c) => c.court.id).toList(), ['a']);
      },
    );
  });

  group('courtsByDistanceFrom', () {
    test('sorts nearest first and attaches the distance', () {
      final courts = courtsByDistanceFrom(
        [_court('far', 1, 0), _court('near', 0.01, 0)],
        0,
        0,
      );

      expect(courts.map((c) => c.court.id).toList(), ['near', 'far']);
      expect(
        courts.first.distanceInMeters,
        lessThan(courts.last.distanceInMeters),
      );
    });

    test('an empty search yields an empty list', () {
      expect(courtsByDistanceFrom(const <Court>[], 0, 0), isEmpty);
    });
  });
}
