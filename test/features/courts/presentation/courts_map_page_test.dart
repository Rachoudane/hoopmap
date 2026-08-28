import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_map_page.dart';
import 'package:hoopmap/features/courts/presentation/widgets/court_marker.dart';

Court _court(String id, String name) => Court(
  id: id,
  name: name,
  latitude: 0,
  longitude: 0,
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
