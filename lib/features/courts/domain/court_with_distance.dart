import 'court.dart';

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
