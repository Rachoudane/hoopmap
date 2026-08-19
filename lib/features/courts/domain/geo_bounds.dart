import 'dart:math';

const double _earthRadiusInMeters = 6371000;

class GeoBounds {
  const GeoBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  factory GeoBounds.aroundPoint(
    double latitude,
    double longitude,
    double radiusInMeters,
  ) {
    final latDeltaInDegrees = radiusInMeters / _earthRadiusInMeters * 180 / pi;
    final lngDeltaInDegrees =
        radiusInMeters /
        (_earthRadiusInMeters * cos(latitude * pi / 180)) *
        180 /
        pi;

    return GeoBounds(
      minLat: (latitude - latDeltaInDegrees).clamp(-90, 90).toDouble(),
      maxLat: (latitude + latDeltaInDegrees).clamp(-90, 90).toDouble(),
      minLng: (longitude - lngDeltaInDegrees).clamp(-180, 180).toDouble(),
      maxLng: (longitude + lngDeltaInDegrees).clamp(-180, 180).toDouble(),
    );
  }

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  double get areaInSquareDegrees => (maxLat - minLat) * (maxLng - minLng);
}
