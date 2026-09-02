import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/court_cluster.dart';
import '../../domain/court_with_distance.dart';
import 'court_cluster_marker.dart';
import 'court_marker.dart';

/// The zoom past which the map stops grouping courts.
///
/// Two courts on the same block are still two courts: at street level the
/// user is looking at exactly the detail clustering throws away, so the
/// grouping is dropped rather than made finer.
const double _maxClusterZoom = 17;

/// How much closer a tapped cluster brings the map. Enough to break most
/// clusters open in one tap, not so much that the user loses their bearings.
const double _clusterZoomStep = 2;

/// The court markers, grouped so they never pile up into an unreadable heap.
///
/// Lives inside [FlutterMap]'s children so it rebuilds with the camera: the
/// grouping is a function of the zoom, and reading the camera from here is
/// what keeps it in step with the map without the page tracking gestures of
/// its own.
class CourtMarkersLayer extends StatelessWidget {
  const CourtMarkersLayer({
    super.key,
    required this.courts,
    required this.mapController,
    required this.selectedCourtId,
    required this.onCourtSelected,
  });

  final List<CourtWithDistance> courts;
  final MapController mapController;
  final String? selectedCourtId;
  final ValueChanged<CourtWithDistance> onCourtSelected;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final maxZoom = camera.maxZoom ?? _maxClusterZoom;
    final clusters = camera.zoom >= _maxClusterZoom
        ? [
            for (final courtWithDistance in courts)
              CourtCluster(
                latitude: courtWithDistance.court.latitude,
                longitude: courtWithDistance.court.longitude,
                courts: [courtWithDistance],
              ),
          ]
        : clusterCourts(courts, zoom: camera.zoom);

    return MarkerLayer(
      markers: [
        for (final cluster in clusters)
          if (cluster.isSingle)
            Marker(
              point: LatLng(
                cluster.single.court.latitude,
                cluster.single.court.longitude,
              ),
              width: AppTouchTarget.minimum,
              height: AppTouchTarget.minimum,
              child: CourtMarker(
                selected: selectedCourtId == cluster.single.court.id,
                onTap: () => onCourtSelected(cluster.single),
              ),
            )
          else
            Marker(
              point: LatLng(cluster.latitude, cluster.longitude),
              width: CourtClusterMarker.size,
              height: CourtClusterMarker.size,
              child: CourtClusterMarker(
                count: cluster.courts.length,
                // Tapping a cluster is a request to see what is inside it,
                // so the map moves in on it rather than opening one of the
                // courts it happens to hold.
                onTap: () => mapController.move(
                  LatLng(cluster.latitude, cluster.longitude),
                  (camera.zoom + _clusterZoomStep).clamp(camera.zoom, maxZoom),
                ),
              ),
            ),
      ],
    );
  }
}
