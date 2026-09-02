import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/location/location_opt_in.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_map_page.dart';
import 'package:hoopmap/features/courts/presentation/widgets/court_cluster_marker.dart';
import 'package:hoopmap/features/courts/presentation/widgets/court_marker.dart';
import 'package:hoopmap/features/courts/presentation/widgets/user_location_marker.dart';

Court _court(String id, String name) => _courtAt(id, name, 0, 0);

Court _courtAt(String id, String name, double latitude, double longitude) =>
    Court(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      hoopCount: 1,
      isOutdoor: true,
      createdAt: DateTime(2026, 1, 1),
    );

/// A user who has already asked for their location. The opt-in gate is what
/// the app opens with, not what these tests are about — they start where a
/// user who pressed "See courts near me" starts.
final _optedIntoLocation = locationOptInProvider.overrideWithBuild(
  (ref, notifier) => true,
);

/// Answers with whichever of [courts] falls inside the requested box, and
/// keeps every box it was asked about — which is how a test can tell that
/// panning searched somewhere new rather than the same place twice.
class _RecordingCourtRepository implements CourtRepository {
  _RecordingCourtRepository(this.courts);

  final List<Court> courts;
  final List<GeoBounds> requestedBounds = [];

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) async* {
    requestedBounds.add(bounds);
    yield courts
        .where(
          (court) =>
              court.latitude >= bounds.minLat &&
              court.latitude <= bounds.maxLat &&
              court.longitude >= bounds.minLng &&
              court.longitude <= bounds.maxLng,
        )
        .toList();
  }

  @override
  Stream<Court> watchCourt(String id) => Stream.error(UnimplementedError());

  @override
  Future<String> addCourt(Court court) => throw UnimplementedError();
}

/// Real [LocationService.currentPosition] orchestration over answers a test
/// controls, so a failure reaches the page the way the device produces it.
class _RecordingLocationService extends LocationService {
  _RecordingLocationService({
    this.serviceEnabled = true,
    this.permission = LocationPermissionStatus.granted,
  });

  final bool serviceEnabled;
  final LocationPermissionStatus permission;

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
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => permission;

  @override
  Future<LocationPermissionStatus> requestPermission() async => permission;

  @override
  Future<UserPosition> readPosition() async =>
      const UserPosition(latitude: 48.8566, longitude: 2.3522);

  @override
  Future<UserPosition?> lastKnownPosition() async => null;
}

/// Drags the map, then lets the settle delay expire so the new viewport
/// becomes a search.
Future<void> _panMap(WidgetTester tester, Offset by) async {
  await tester.drag(find.byType(FlutterMap), by);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  testWidgets('displays a FlutterMap with one marker per court', (
    tester,
  ) async {
    // Far enough apart to be drawn separately at the map's opening zoom,
    // close enough to all be on screen.
    final courts = [
      CourtWithDistance(
        court: _courtAt('court-a', 'Court A', 0, 0),
        distanceInMeters: 450,
      ),
      CourtWithDistance(
        court: _courtAt('court-b', 'Court B', 0.02, 0),
        distanceInMeters: 1200,
      ),
      CourtWithDistance(
        court: _courtAt('court-c', 'Court C', 0.04, 0),
        distanceInMeters: 2400,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            yield courts;
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(CourtMarker), findsNWidgets(3));
    expect(find.byType(CourtClusterMarker), findsNothing);
  });

  testWidgets('courts too close to draw apart share one counted cluster', (
    tester,
  ) async {
    // Metres apart: three separate pins here would be an unreadable pile.
    final courts = [
      for (var i = 0; i < 3; i++)
        CourtWithDistance(
          court: _courtAt('court-$i', 'Court $i', 0.0001 * i, 0),
          distanceInMeters: 100.0 * i,
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            yield courts;
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(CourtMarker), findsNothing);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping a cluster zooms in on it, which breaks it apart', (
    tester,
  ) async {
    // Close enough to cluster at zoom 13, far enough to separate a few
    // zoom levels in.
    final courts = [
      CourtWithDistance(
        court: _courtAt('court-a', 'Court A', 0, 0),
        distanceInMeters: 100,
      ),
      CourtWithDistance(
        court: _courtAt('court-b', 'Court B', 0.008, 0),
        distanceInMeters: 900,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            yield courts;
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(CourtClusterMarker), findsOneWidget);
    final zoomBefore = MapCamera.of(
      tester.element(find.byType(TileLayer)),
    ).zoom;

    await tester.tap(find.byType(CourtClusterMarker));
    await tester.pumpAndSettle();

    expect(
      MapCamera.of(tester.element(find.byType(TileLayer))).zoom,
      greaterThan(zoomBefore),
    );
    expect(find.byType(CourtClusterMarker), findsNothing);
    expect(find.byType(CourtMarker), findsNWidgets(2));
  });

  testWidgets('tapping a marker opens a preview card for that court', (
    tester,
  ) async {
    final courts = [
      CourtWithDistance(
        court: _court('court-a', 'Court A'),
        distanceInMeters: 450,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            yield courts;
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Court A'), findsNothing);

    await tester.tap(find.byType(CourtMarker));
    await tester.pump();

    expect(find.text('Court A'), findsOneWidget);
    expect(find.text('450 m'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('Court A'), findsNothing);
  });

  testWidgets(
    'keeps the map visible and says so when there are no courts nearby',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
              yield const [];
            }),
          ],
          child: const MaterialApp(home: CourtsMapPage()),
        ),
      );
      await tester.pump();

      expect(find.text(AppStrings.noCourtsNearbyMapMessage), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
    },
  );

  testWidgets('shows a human-readable error with a working retry button, '
      'over a map that is still there', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            throw Exception('boom');
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // The whole point: a failure costs the user the courts, never the map.
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets(
    'renders the map immediately while the position fix is still pending',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
              // Never yields: still waiting on the location fix.
            }),
          ],
          child: const MaterialApp(home: CourtsMapPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text(AppStrings.mapLocatingYou), findsOneWidget);
      // Tiles, not a bare full-screen spinner in place of the map.
      expect(find.byType(TileLayer), findsOneWidget);
    },
  );

  testWidgets('centres on the user, not on the nearest court', (tester) async {
    // The nearest court is deliberately far from the user: centring on it
    // would push the user off their own map.
    final courts = [
      CourtWithDistance(
        court: _courtAt('far', 'Far court', 45.7640, 4.8357),
        distanceInMeters: 4500,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPositionProvider.overrideWith(
            (ref) async =>
                const UserPosition(latitude: 48.8566, longitude: 2.3522),
          ),
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            yield courts;
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final camera = MapCamera.of(tester.element(find.byType(TileLayer)));
    expect(camera.center.latitude, closeTo(48.8566, 0.0001));
    expect(camera.center.longitude, closeTo(2.3522, 0.0001));
  });

  testWidgets(
    'falls back to the nearest court when there is no position at all',
    (tester) async {
      final courts = [
        CourtWithDistance(
          court: _courtAt('near', 'Near court', 45.7640, 4.8357),
          distanceInMeters: 300,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userPositionProvider.overrideWith(
              (ref) async => throw const LocationPermissionDeniedException(),
            ),
            nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
              yield courts;
            }),
          ],
          child: const MaterialApp(home: CourtsMapPage()),
        ),
      );
      await tester.pump();
      await tester.pump();

      final camera = MapCamera.of(tester.element(find.byType(TileLayer)));
      expect(camera.center.latitude, closeTo(45.7640, 0.0001));
      expect(camera.center.longitude, closeTo(4.8357, 0.0001));
    },
  );

  testWidgets('draws the user dot and an accuracy circle at their position', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPositionProvider.overrideWith(
            (ref) async => const UserPosition(
              latitude: 48.8566,
              longitude: 2.3522,
              accuracyInMeters: 30,
            ),
          ),
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            yield const <CourtWithDistance>[];
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(UserLocationMarker), findsOneWidget);

    final circleLayer = tester.widget<CircleLayer>(find.byType(CircleLayer));
    expect(circleLayer.circles, hasLength(1));
    final circle = circleLayer.circles.single;
    expect(circle.radius, 30);
    expect(circle.useRadiusInMeter, isTrue);
    expect(circle.point.latitude, closeTo(48.8566, 0.0001));
  });

  testWidgets('draws no accuracy circle when the device reports no accuracy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPositionProvider.overrideWith(
            (ref) async =>
                const UserPosition(latitude: 48.8566, longitude: 2.3522),
          ),
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            yield const <CourtWithDistance>[];
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The dot is still shown — only the uncertainty the device never
    // reported is left undrawn.
    expect(find.byType(UserLocationMarker), findsOneWidget);
    expect(find.byType(CircleLayer), findsNothing);
  });

  testWidgets('draws no user dot while the position is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPositionProvider.overrideWith(
            (ref) async => throw const LocationPermissionDeniedException(),
          ),
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            yield const <CourtWithDistance>[];
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(UserLocationMarker), findsNothing);
    expect(find.byType(CircleLayer), findsNothing);
  });

  testWidgets('a location permission failure still leaves a pannable map', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            throw const LocationPermissionDeniedException();
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text(AppStrings.errorLocationPermissionDenied), findsOneWidget);
  });

  testWidgets('panning searches the area the map was moved to', (tester) async {
    final repository = _RecordingCourtRepository([
      _courtAt('home', 'Home court', 48.8566, 2.3522),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _optedIntoLocation,
          locationServiceProvider.overrideWithValue(
            _RecordingLocationService(),
          ),
          courtRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pumpAndSettle();

    // The first search is the 5 km around the user, as before.
    expect(repository.requestedBounds, hasLength(1));
    final aroundUser = repository.requestedBounds.single;
    expect(aroundUser.centerLat, closeTo(48.8566, 0.001));

    await _panMap(tester, const Offset(-400, -400));

    expect(repository.requestedBounds.length, greaterThan(1));
    final afterPan = repository.requestedBounds.last;
    // South-east of where the map started: dragging the map up and to the
    // left moves the viewport the other way.
    expect(afterPan.centerLat, lessThan(aroundUser.centerLat));
    expect(afterPan.centerLng, greaterThan(aroundUser.centerLng));
  });

  testWidgets('the courts of the area panned to replace the ones left behind', (
    tester,
  ) async {
    // Far enough apart that no viewport holds both.
    final repository = _RecordingCourtRepository([
      _courtAt('home', 'Home court', 48.8566, 2.3522),
      _courtAt('away', 'Away court', 40, 20),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _optedIntoLocation,
          locationServiceProvider.overrideWithValue(
            _RecordingLocationService(),
          ),
          courtRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CourtMarker), findsOneWidget);

    // A pan that lands on nothing: the map has to say so rather than keep
    // showing the courts of the place the user left.
    await _panMap(tester, const Offset(-2000, 0));
    await tester.pumpAndSettle();

    expect(find.byType(CourtMarker), findsNothing);
    expect(find.text(AppStrings.noCourtsNearbyMapMessage), findsOneWidget);
  });

  testWidgets('a viewport that never moves is never searched twice', (
    tester,
  ) async {
    final repository = _RecordingCourtRepository([
      _courtAt('home', 'Home court', 48.8566, 2.3522),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _optedIntoLocation,
          locationServiceProvider.overrideWithValue(
            _RecordingLocationService(),
          ),
          courtRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Laying the map out reports a viewport of its own; only a gesture may
    // turn one into an Overpass query.
    expect(repository.requestedBounds, hasLength(1));
  });

  testWidgets('recentring on the user goes back to the courts around them', (
    tester,
  ) async {
    final repository = _RecordingCourtRepository([
      _courtAt('home', 'Home court', 48.8566, 2.3522),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _optedIntoLocation,
          locationServiceProvider.overrideWithValue(
            _RecordingLocationService(),
          ),
          courtRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pumpAndSettle();

    await _panMap(tester, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(find.byType(CourtMarker), findsNothing);

    await tester.tap(find.byTooltip(AppStrings.recenterOnMyLocation));
    await tester.pumpAndSettle();

    expect(find.byType(CourtMarker), findsOneWidget);
  });

  testWidgets('the banner sends a permanently denied permission to the app '
      'settings instead of offering Retry', (tester) async {
    final service = _RecordingLocationService(
      permission: LocationPermissionStatus.deniedForever,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _optedIntoLocation,
          locationServiceProvider.overrideWithValue(service),
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            throw const LocationPermissionPermanentlyDeniedException();
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();

    expect(
      find.text(AppStrings.errorLocationPermissionPermanentlyDenied),
      findsOneWidget,
    );
    // One button fits on the banner, and retrying a permission the system
    // will not prompt for again can only fail again.
    expect(find.text(AppStrings.retry), findsNothing);

    await tester.tap(find.text(AppStrings.openAppSettings));
    await tester.pump();

    expect(service.openAppSettingsCallCount, 1);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('the banner sends a disabled location service to the location '
      'settings', (tester) async {
    final service = _RecordingLocationService(serviceEnabled: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _optedIntoLocation,
          locationServiceProvider.overrideWithValue(service),
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            throw const LocationServiceDisabledException();
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.openLocationSettings));
    await tester.pump();

    expect(service.openLocationSettingsCallCount, 1);
  });

  testWidgets('a failed recentre offers the way out from the snack bar', (
    tester,
  ) async {
    final service = _RecordingLocationService(
      permission: LocationPermissionStatus.deniedForever,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _optedIntoLocation,
          locationServiceProvider.overrideWithValue(service),
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            yield const <CourtWithDistance>[];
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip(AppStrings.recenterOnMyLocation));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.locationUnavailableSnackBar), findsOneWidget);

    await tester.tap(find.text(AppStrings.openAppSettings));
    await tester.pump();

    expect(service.openAppSettingsCallCount, 1);
  });

  testWidgets('the banner offers the user their own location before it has '
      'been asked for', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(
            _RecordingLocationService(),
          ),
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            throw const LocationNotRequestedException();
          }),
        ],
        child: const MaterialApp(home: CourtsMapPage()),
      ),
    );
    await tester.pump();

    // The map is there to browse either way; the banner is an offer on top
    // of it, not an error in place of it.
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text(AppStrings.locationNotRequestedShort), findsOneWidget);
    expect(find.text(AppStrings.useMyLocation), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
  });
}
