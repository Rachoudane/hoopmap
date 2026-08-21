import 'dart:math';

const double _earthRadiusInMeters = 6371000;

double distanceInMetersBetween(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final lat1Rad = lat1 * pi / 180;
  final lat2Rad = lat2 * pi / 180;
  final deltaLatRad = (lat2 - lat1) * pi / 180;
  final deltaLonRad = (lon2 - lon1) * pi / 180;

  final a =
      sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
      cos(lat1Rad) * cos(lat2Rad) * sin(deltaLonRad / 2) * sin(deltaLonRad / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return _earthRadiusInMeters * c;
}

/// Formats a distance for display: meters below 1 km, kilometers with one
/// decimal (comma-separated, French locale) above.
String formatDistanceLabel(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  final kilometers = (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return '$kilometers km';
}
