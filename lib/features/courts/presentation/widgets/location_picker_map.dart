import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_attribution.dart';

/// A map with a reticle fixed at its visual center: panning the map moves
/// the target underneath it, which [onCenterChanged] reports as the
/// candidate position for the new court. A symmetric crosshair (rather
/// than a pin) is used deliberately so the icon's visual center exactly
/// matches the reported coordinate — a pin's point would sit below its
/// bounding box center, off by half its height.
class LocationPickerMap extends StatelessWidget {
  const LocationPickerMap({
    super.key,
    required this.mapController,
    required this.initialCenter,
    required this.onCenterChanged,
  });

  final MapController mapController;
  final LatLng initialCenter;
  final ValueChanged<LatLng> onCenterChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 15,
            onPositionChanged: (camera, hasGesture) =>
                onCenterChanged(camera.center),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rachoucorp.hoopmap',
            ),
            const MapAttribution(),
          ],
        ),
        IgnorePointer(
          child: Icon(
            Icons.gps_fixed,
            size: 36,
            color: colorScheme.primary,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
          ),
        ),
      ],
    );
  }
}
