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

  /// The middle of the box. Like [GeoBounds.aroundPoint], this assumes a box
  /// that does not straddle the antimeridian.
  double get centerLat => (minLat + maxLat) / 2;
  double get centerLng => (minLng + maxLng) / 2;

  /// Value equality, so bounds can key a provider: two viewports describing
  /// the same box must resolve to the same search rather than a second
  /// identical Overpass query.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeoBounds &&
        other.minLat == minLat &&
        other.maxLat == maxLat &&
        other.minLng == minLng &&
        other.maxLng == maxLng;
  }

  @override
  int get hashCode => Object.hash(minLat, maxLat, minLng, maxLng);

  @override
  String toString() => 'GeoBounds($minLat, $minLng, $maxLat, $maxLng)';
}
