import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_map_page.dart';
import 'package:hoopmap/features/courts/presentation/widgets/court_marker.dart';

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

void main() {
  testWidgets('displays a FlutterMap with one marker per court', (
    tester,
  ) async {
    final courts = [
      CourtWithDistance(
        court: _court('court-a', 'Court A'),
        distanceInMeters: 450,
      ),
      CourtWithDistance(
        court: _court('court-b', 'Court B'),
        distanceInMeters: 1200,
      ),
      CourtWithDistance(
        court: _court('court-c', 'Court C'),
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

    final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markerLayer.markers, hasLength(3));
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
}
