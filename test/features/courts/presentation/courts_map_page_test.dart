import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_map_page.dart';

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
        court: _court('court-a', 'Terrain A'),
        distanceInMeters: 450,
      ),
      CourtWithDistance(
        court: _court('court-b', 'Terrain B'),
        distanceInMeters: 1200,
      ),
      CourtWithDistance(
        court: _court('court-c', 'Terrain C'),
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
}
