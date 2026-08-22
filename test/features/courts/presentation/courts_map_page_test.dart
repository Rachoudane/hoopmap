import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('shows an illustrated empty state when there are no courts', (
    tester,
  ) async {
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

    expect(find.text('No courts nearby'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('shows a human-readable error with a working retry button', (
    tester,
  ) async {
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
  });
}
