import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/presentation/widgets/app_message_view.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/court_with_distance.dart';
import '../court_error_messages.dart';
import '../nearby_courts_notifier.dart';
import '../widgets/court_marker.dart';
import '../widgets/court_preview_card.dart';

class CourtsMapPage extends ConsumerStatefulWidget {
  const CourtsMapPage({super.key});

  @override
  ConsumerState<CourtsMapPage> createState() => _CourtsMapPageState();
}

class _CourtsMapPageState extends ConsumerState<CourtsMapPage> {
  final _mapController = MapController();
  CourtWithDistance? _selected;
  bool _recentering = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _recenterOnUser() async {
    setState(() => _recentering = true);
    try {
      final position = await ref
          .read(locationServiceProvider)
          .currentPosition();
      _mapController.move(LatLng(position.latitude, position.longitude), 14);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.locationUnavailableSnackBar)),
      );
    } finally {
      if (mounted) setState(() => _recentering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courtsAsync = ref.watch(nearbyCourtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.mapTitle)),
      body: courtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AppErrorView(
          message: courtErrorMessage(error),
          icon: courtErrorIcon(error),
          onRetry: () => ref.invalidate(nearbyCourtsProvider),
        ),
        data: (courts) {
          if (courts.isEmpty) {
            return AppEmptyView(
              icon: Icons.map_outlined,
              title: AppStrings.noCourtsNearbyTitle,
              message: AppStrings.noCourtsNearbyMapMessage,
              actionLabel: AppStrings.refresh,
              onAction: () => ref.invalidate(nearbyCourtsProvider),
            );
          }

          final center = LatLng(
            courts.first.court.latitude,
            courts.first.court.longitude,
          );

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                  onTap: (_, _) => setState(() => _selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                          width: 48,
                          height: 48,
                          child: CourtMarker(
                            selected:
                                _selected?.court.id ==
                                courtWithDistance.court.id,
                            onTap: () =>
                                setState(() => _selected = courtWithDistance),
                          ),
                        ),
                    ],
                  ),
                  const Align(
                    alignment: Alignment.bottomLeft,
                    // SimpleAttributionWidget already renders
                    // 'flutter_map | © ' before source, so source itself
                    // must not repeat the © symbol.
                    child: SimpleAttributionWidget(
                      source: Text(AppStrings.openStreetMapContributors),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: AppSpacing.lg,
                right: AppSpacing.lg,
                // A default-sized (56dp) FAB, not .small (40dp, below the
                // 48dp minimum touch target).
                child: FloatingActionButton(
                  heroTag: 'recenter',
                  onPressed: _recentering ? null : _recenterOnUser,
                  tooltip: AppStrings.recenterOnMyLocation,
                  child: _recentering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
              if (_selected case final selected?)
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  // Clears the OpenStreetMap attribution pinned to the
                  // map's bottom-left corner.
                  bottom: AppSpacing.xxxl,
                  child: CourtPreviewCard(
                    courtWithDistance: selected,
                    onClose: () => setState(() => _selected = null),
                    onOpenDetail: () => context.pushNamed(
                      Routes.courtDetailName,
                      pathParameters: {Routes.courtIdParam: selected.court.id},
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
