import 'dart:math';

import 'court_with_distance.dart';

/// The courts drawn as a single marker, and where that marker goes.
///
/// A cluster of one is an ordinary court marker: the map draws both from the
/// same list, so nothing has to decide twice whether a given court is on its
/// own.
class CourtCluster {
  const CourtCluster({
    required this.latitude,
    required this.longitude,
    required this.courts,
  });

  final double latitude;
  final double longitude;
  final List<CourtWithDistance> courts;

  bool get isSingle => courts.length == 1;

  /// The one court in this cluster. Only valid when [isSingle].
  CourtWithDistance get single => courts.single;

  /// Identifies the cluster across rebuilds — the courts it holds, in the
  /// order they were grouped.
  String get id => courts.map((c) => c.court.id).join('+');
}

/// How much room a marker takes on screen. Courts closer together than this
/// would overlap into an unreadable pile, which is what clustering exists to
/// avoid.
const double _clusterCellInPixels = 88;

const double _tileSizeInPixels = 256;

/// Groups the courts that would overlap at [zoom] into one marker each.
///
/// Grid clustering: the world is cut into square cells of a fixed size *in
/// screen pixels*, and every court in a cell becomes one marker at the middle
/// of the ones it holds. Because the cell is measured in pixels, zooming in
/// splits clusters apart on its own — the same courts simply fall into
/// different cells — and no state has to be kept between zoom levels.
///
/// The grid is anchored to the world, not to the viewport, so panning cannot
/// reshuffle which courts are grouped together: the same courts cluster the
/// same way wherever the map happens to be scrolled.
List<CourtCluster> clusterCourts(
  List<CourtWithDistance> courts, {
  required double zoom,
  double cellSizeInPixels = _clusterCellInPixels,
}) {
  if (courts.isEmpty) return const [];

  final worldSize = _tileSizeInPixels * pow(2, zoom);
  final grouped = <(int, int), List<CourtWithDistance>>{};

  for (final courtWithDistance in courts) {
    final court = courtWithDistance.court;
    final x = _mercatorX(court.longitude) * worldSize;
    final y = _mercatorY(court.latitude) * worldSize;
    final cell = (
      (x / cellSizeInPixels).floor(),
      (y / cellSizeInPixels).floor(),
    );
    grouped.putIfAbsent(cell, () => []).add(courtWithDistance);
  }

  // Insertion order is the input order, so a list already sorted by distance
  // yields clusters in that same order — the nearest court still leads.
  return [
    for (final members in grouped.values)
      CourtCluster(
        latitude:
            members.map((c) => c.court.latitude).reduce((a, b) => a + b) /
            members.length,
        longitude:
            members.map((c) => c.court.longitude).reduce((a, b) => a + b) /
            members.length,
        courts: members,
      ),
  ];
}

/// Web Mercator, normalized to 0..1 — the projection the map tiles use, so
/// grouping by cell matches what the user actually sees overlapping.
double _mercatorX(double longitude) => (longitude + 180) / 360;

double _mercatorY(double latitude) {
  // Clamped just short of the poles, where the projection goes to infinity.
  final clamped = latitude.clamp(-85.05112878, 85.05112878);
  final latRad = clamped * pi / 180;
  return 0.5 - log(tan(pi / 4 + latRad / 2)) / (2 * pi);
}
