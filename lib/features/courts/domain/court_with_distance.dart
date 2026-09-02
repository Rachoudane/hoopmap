import 'court.dart';
import 'distance.dart';

class CourtWithDistance {
  const CourtWithDistance({
    required this.court,
    required this.distanceInMeters,
  });

  final Court court;
  final double distanceInMeters;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CourtWithDistance &&
        other.court == court &&
        other.distanceInMeters == distanceInMeters;
  }

  @override
  int get hashCode => Object.hash(court, distanceInMeters);
}

/// [courts] paired with their distance from ([latitude], [longitude]),
/// nearest first.
///
/// Shared by every court search: the origin differs (the user's own position
/// for the nearby list, the middle of the viewport when the map is driving
/// the search) but "nearest first, with the distance attached" does not.
List<CourtWithDistance> courtsByDistanceFrom(
  Iterable<Court> courts,
  double latitude,
  double longitude,
) =>
    courts
        .map(
          (court) => CourtWithDistance(
            court: court,
            distanceInMeters: distanceInMetersBetween(
              latitude,
              longitude,
              court.latitude,
              court.longitude,
            ),
          ),
        )
        .toList()
      ..sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
