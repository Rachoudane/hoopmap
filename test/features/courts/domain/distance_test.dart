import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/domain/distance.dart';

void main() {
  group('distanceInMetersBetween', () {
    test('matches the known great-circle distance between Paris and Lyon', () {
      // Paris (48.8566, 2.3522) to Lyon (45.7640, 4.8357): the documented
      // straight-line distance is ~392 km (e.g. https://www.distance.to/Paris/Lyon).
      final distance = distanceInMetersBetween(48.8566, 2.3522, 45.764, 4.8357);

      expect(distance, closeTo(392000, 2000));
    });

    test('is zero for a point compared to itself', () {
      final distance = distanceInMetersBetween(
        48.8566,
        2.3522,
        48.8566,
        2.3522,
      );

      expect(distance, 0);
    });

    test('is symmetric', () {
      final a = distanceInMetersBetween(48.8566, 2.3522, 45.764, 4.8357);
      final b = distanceInMetersBetween(45.764, 4.8357, 48.8566, 2.3522);

      expect(a, b);
    });
  });

  group('formatDistanceLabel', () {
    test('rounds sub-kilometer distances to whole meters', () {
      expect(formatDistanceLabel(450), '450 m');
      expect(formatDistanceLabel(999.6), '1000 m');
    });

    test('formats kilometer distances with a comma decimal', () {
      expect(formatDistanceLabel(1200), '1,2 km');
      expect(formatDistanceLabel(2400), '2,4 km');
    });

    test('the 1000 m boundary is formatted in kilometers', () {
      expect(formatDistanceLabel(1000), '1,0 km');
    });
  });
}
