import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/location/location_opt_in.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/court_with_distance.dart';
import '../../domain/geo_bounds.dart';
import '../court_error_messages.dart';
import '../map_courts_provider.dart';
import '../nearby_courts_notifier.dart';
import '../widgets/court_markers_layer.dart';
import '../widgets/court_preview_card.dart';
import '../widgets/user_location_marker.dart';

// Where the map starts before anything is known about the user's position.
// Normally visible only for the moment the first fix takes to resolve — and
// when it can't resolve at all, it leaves a real map to pan instead of an
// error screen.
const LatLng _initialMapCenter = LatLng(48.8566, 2.3522);
const double _initialMapZoom = 13;
const double _recenterZoom = 14;

// How long the map has to sit still before its viewport becomes a search.
// A pan or a pinch produces a camera update per frame; searching on each one
// would fire dozens of Overpass queries to answer the single question the
// user asks when they stop moving.
const Duration _boundsSettleDelay = Duration(milliseconds: 600);

class CourtsMapPage extends ConsumerStatefulWidget {
  const CourtsMapPage({super.key});

  @override
  ConsumerState<CourtsMapPage> createState() => _CourtsMapPageState();
}

class _CourtsMapPageState extends ConsumerState<CourtsMapPage> {
  final _mapController = MapController();
  CourtWithDistance? _selected;
  bool _recentering = false;
  Timer? _boundsSettleTimer;

  // MapController.move() throws until the map has been laid out, and the
  // position can resolve either side of that, so both conditions are tracked
  // and whichever happens last performs the move.
  bool _mapReady = false;
  bool _centered = false;

  @override
  void dispose() {
    _boundsSettleTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Turns the camera the user left behind into the area to search, once it
  /// has stopped moving.
  ///
  /// Only gestures count. Every programmatic move the page makes itself
  /// (centring on the first fix, recentring) already knows which courts it
  /// wants, and letting those moves feed back in here would search twice for
  /// the same place.
  void _onCameraChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;

    // The camera now belongs to the user: no later arrival of courts or of a
    // position may move it back under them.
    _centered = true;

    _boundsSettleTimer?.cancel();
    _boundsSettleTimer = Timer(_boundsSettleDelay, () {
      if (!mounted) return;
      final visible = camera.visibleBounds;
      ref.read(visibleMapBoundsProvider.notifier).bounds = GeoBounds(
        minLat: visible.south,
        maxLat: visible.north,
        minLng: visible.west,
        maxLng: visible.east,
      );
    });
  }

  /// Centres the map once, on the user if their position is known and on the
  /// nearest court otherwise. Any later camera change belongs to the user.
  ///
  /// The user's own position is what the map should open on: the nearest
  /// court can be kilometres away in an arbitrary direction, which puts the
  /// user off-screen on their own map and makes the distances on every marker
  /// impossible to read against anything. The nearest court is only a
  /// fallback for when there is no position at all — still better than a
  /// hardcoded city.
  void _centerIfNeeded() {
    if (_centered || !_mapReady) return;

    final position = ref.read(userPositionProvider).value;
    if (position != null) {
      _centered = true;
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _initialMapZoom,
      );
      return;
    }

    // No position: fall back to the nearest court, but don't latch — a
    // position arriving later should still win.
    final courts = ref.read(nearbyCourtsProvider).value;
    if (courts == null || courts.isEmpty) return;
    _mapController.move(
      LatLng(courts.first.court.latitude, courts.first.court.longitude),
      _initialMapZoom,
    );
  }

  Future<void> _recenterOnUser() async {
    setState(() => _recentering = true);
    try {
      final position = await ref
          .read(locationServiceProvider)
          .currentPosition();
      // Coming back to the user means coming back to their courts: the
      // viewport the search was following is no longer the area of interest.
      _boundsSettleTimer?.cancel();
      ref.read(visibleMapBoundsProvider.notifier).clear();
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _recenterZoom,
      );
    } catch (error) {
      if (!mounted) return;
      final recovery = courtErrorRecovery(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.locationUnavailableSnackBar),
          // A snack bar the user can act on: the settings screen that can
          // unblock this is one tap away instead of a hunt through the
          // system settings.
          action: recovery == null
              ? null
              : SnackBarAction(
                  label: locationRecoveryLabel(recovery),
                  onPressed: () => openLocationRecovery(
                    ref.read(locationServiceProvider),
                    recovery,
                  ),
                ),
        ),
      );
    } finally {
      if (mounted) setState(() => _recentering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Until the user moves the map, it shows the same search as the list:
    // the courts around them. From the first pan on, the visible box is the
    // search, so panning to another neighbourhood shows that neighbourhood's
    // courts rather than an empty map.
    final visibleBounds = ref.watch(visibleMapBoundsProvider);
    final courtsProvider = visibleBounds == null
        ? nearbyCourtsProvider
        : courtsInBoundsProvider(visibleBounds);
    final courtsAsync = ref.watch(courtsProvider);

    // A position, or courts, resolving after the map has been laid out.
    ref.listen(userPositionProvider, (previous, next) => _centerIfNeeded());
    ref.listen(courtsProvider, (previous, next) => _centerIfNeeded());

    final courts = courtsAsync.value ?? const <CourtWithDistance>[];
    void reloadCourts() => ref.invalidate(courtsProvider);
    final userPosition = ref.watch(userPositionProvider).value;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.mapTitle)),
      // The map is built unconditionally: waiting on a position fix, or
      // failing to get one, must never cost the user the map itself. The
      // loading, error and empty states are overlaid on top of it, and the
      // map stays pannable underneath all three.
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialMapCenter,
              initialZoom: _initialMapZoom,
              onMapReady: () {
                _mapReady = true;
                // A position that resolved before the map was laid out.
                _centerIfNeeded();
              },
              onTap: (_, _) => setState(() => _selected = null),
              onPositionChanged: _onCameraChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rachoucorp.hoopmap',
              ),
              // Below the court markers: the user's own position must never
              // sit on top of something they're trying to tap.
              if (userPosition?.accuracyInMeters case final accuracy?)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(
                        userPosition!.latitude,
                        userPosition.longitude,
                      ),
                      radius: accuracy,
                      useRadiusInMeter: true,
                      color: colorScheme.secondary.withValues(alpha: 0.15),
                      borderColor: colorScheme.secondary.withValues(alpha: 0.4),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              if (userPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        userPosition.latitude,
                        userPosition.longitude,
                      ),
                      width: UserLocationMarker.size,
                      height: UserLocationMarker.size,
                      child: const UserLocationMarker(),
                    ),
                  ],
                ),
              CourtMarkersLayer(
                courts: courts,
                mapController: _mapController,
                selectedCourtId: _selected?.court.id,
                onCourtSelected: (courtWithDistance) =>
                    setState(() => _selected = courtWithDistance),
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
            left: AppSpacing.lg,
            // Clears the recenter FAB (56dp) pinned to the same corner.
            right: AppSpacing.lg + 56 + AppSpacing.md,
            child: _MapStatusBanner(
              courtsAsync: courtsAsync,
              onReload: reloadCourts,
            ),
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
      ),
    );
  }
}

/// Compact status card floated over the map while courts are loading, when
/// they failed to load, or when there are none.
///
/// Deliberately not `AppErrorView`/`AppEmptyView`: those fill the body and
/// would hide the map. Here the map has to stay visible and usable, so the
/// message takes as little room as it can and leaves the rest tappable.
class _MapStatusBanner extends ConsumerWidget {
  const _MapStatusBanner({required this.courtsAsync, required this.onReload});

  final AsyncValue<List<CourtWithDistance>> courtsAsync;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (courtsAsync) {
      AsyncLoading() => const _BannerCard(
        icon: Icons.my_location,
        message: AppStrings.mapLocatingYou,
        showProgress: true,
      ),
      // The banner has room for one button, so it goes to whatever will
      // actually move the situation on. Offering the user's own location is
      // ahead of Retry (there is nothing to retry yet), and so is the system
      // screen behind a permanent denial — retrying that can only fail
      // again.
      AsyncError(error: LocationNotRequestedException()) => _BannerCard(
        icon: Icons.my_location,
        message: AppStrings.locationNotRequestedShort,
        actionLabel: AppStrings.useMyLocation,
        onAction: () => ref.read(locationOptInProvider.notifier).optIn(),
      ),
      AsyncError(:final error) => _BannerCard(
        icon: courtErrorIcon(error),
        message: courtErrorMessage(error),
        actionLabel: switch (courtErrorRecovery(error)) {
          final recovery? => locationRecoveryLabel(recovery),
          null => AppStrings.retry,
        },
        onAction: switch (courtErrorRecovery(error)) {
          final recovery? => () => openLocationRecovery(
            ref.read(locationServiceProvider),
            recovery,
          ),
          null => onReload,
        },
      ),
      AsyncData(value: final courts) when courts.isEmpty => _BannerCard(
        icon: Icons.sports_basketball_outlined,
        message: AppStrings.noCourtsNearbyMapMessage,
        actionLabel: AppStrings.refresh,
        onAction: onReload,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.showProgress = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (showProgress)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
