import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/app.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';

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
  testWidgets(
    'displays courts sorted by distance with formatted distances, and '
    'navigates to detail on tap',
    (tester) async {
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
          child: const HoopmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terrain A'), findsOneWidget);
      expect(find.text('Terrain B'), findsOneWidget);
      expect(find.text('Terrain C'), findsOneWidget);
      expect(find.text('450 m'), findsOneWidget);
      expect(find.text('1,2 km'), findsOneWidget);

      final positionA = tester.getCenter(find.text('Terrain A')).dy;
      final positionB = tester.getCenter(find.text('Terrain B')).dy;
      final positionC = tester.getCenter(find.text('Terrain C')).dy;
      expect(positionA, lessThan(positionB));
      expect(positionB, lessThan(positionC));

      await tester.tap(find.text('Terrain A'));
      await tester.pumpAndSettle();

      final detailPage = tester.widget<CourtDetailPage>(
        find.byType(CourtDetailPage),
      );
      expect(detailPage.courtId, 'court-a');
    },
  );
}
