import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/domain/distance.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';

void main() {
  group('GeoBounds.aroundPoint', () {
    test(
      'produces a box whose height matches twice the radius within a few meters',
      () {
        const latitude = 48.8566;
        const longitude = 2.3522;
        const radius = 5000.0;

        final bounds = GeoBounds.aroundPoint(latitude, longitude, radius);

        final heightInMeters = distanceInMetersBetween(
          bounds.minLat,
          longitude,
          bounds.maxLat,
          longitude,
        );
        expect(heightInMeters, closeTo(radius * 2, 5));
      },
    );

    test('produces a box whose width matches twice the radius within a few '
        'meters at the equator', () {
      const latitude = 0.0;
      const longitude = 0.0;
      const radius = 5000.0;

      final bounds = GeoBounds.aroundPoint(latitude, longitude, radius);

      final widthInMeters = distanceInMetersBetween(
        latitude,
        bounds.minLng,
        latitude,
        bounds.maxLng,
      );
      expect(widthInMeters, closeTo(radius * 2, 5));
    });

    test('the longitude span is wider near a pole than at the equator for the '
        'same radius', () {
      const radius = 5000.0;

      final equatorBounds = GeoBounds.aroundPoint(0, 0, radius);
      final nearPoleBounds = GeoBounds.aroundPoint(80, 0, radius);

      final equatorLngSpan = equatorBounds.maxLng - equatorBounds.minLng;
      final nearPoleLngSpan = nearPoleBounds.maxLng - nearPoleBounds.minLng;

      expect(nearPoleLngSpan, greaterThan(equatorLngSpan));
    });

    test('keeps latitude and longitude within valid ranges near the pole', () {
      final bounds = GeoBounds.aroundPoint(89.9, 0, 500000);

      expect(bounds.minLat, greaterThanOrEqualTo(-90));
      expect(bounds.maxLat, lessThanOrEqualTo(90));
      expect(bounds.minLng, greaterThanOrEqualTo(-180));
      expect(bounds.maxLng, lessThanOrEqualTo(180));
    });
  });
}
