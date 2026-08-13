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
}
