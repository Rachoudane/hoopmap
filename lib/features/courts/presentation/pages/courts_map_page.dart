import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/router/routes.dart';
import '../nearby_courts_notifier.dart';

const LatLng _lilleCenter = LatLng(50.6292, 3.0573);

class CourtsMapPage extends ConsumerWidget {
  const CourtsMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtsAsync = ref.watch(nearbyCourtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Carte')),
      body: courtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Erreur : ${error.runtimeType}')),
        data: (courts) {
          final center = courts.isEmpty
              ? _lilleCenter
              : LatLng(
                  courts.first.court.latitude,
                  courts.first.court.longitude,
                );

          return FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rachoucorp.hoopmap',
              ),
              MarkerLayer(
                markers: [
                  for (final courtWithDistance in courts)
                    Marker(
                      point: LatLng(
                        courtWithDistance.court.latitude,
                        courtWithDistance.court.longitude,
                      ),
                      child: GestureDetector(
                        onTap: () => context.goNamed(
                          Routes.courtDetailName,
                          pathParameters: {
                            Routes.courtIdParam: courtWithDistance.court.id,
                          },
                        ),
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          );
        },
      ),
    );
  }
}
