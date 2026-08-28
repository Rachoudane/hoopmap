import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/court_with_distance.dart';
import '../court_error_messages.dart';
import '../nearby_courts_notifier.dart';
import '../widgets/court_marker.dart';
import '../widgets/court_preview_card.dart';

// Where the map starts before anything is known about the user's position.
// Normally visible only for the moment the first fix takes to resolve — and
// when it can't resolve at all, it leaves a real map to pan instead of an
// error screen.
const LatLng _initialMapCenter = LatLng(48.8566, 2.3522);
const double _initialMapZoom = 13;
const double _recenterZoom = 14;

class CourtsMapPage extends ConsumerStatefulWidget {
  const CourtsMapPage({super.key});

  @override
  ConsumerState<CourtsMapPage> createState() => _CourtsMapPageState();
}

class _CourtsMapPageState extends ConsumerState<CourtsMapPage> {
  final _mapController = MapController();
  CourtWithDistance? _selected;
  bool _recentering = false;

  // MapController.move() throws until the map has been laid out, and the
  // position can resolve either side of that, so both conditions are tracked
  // and whichever happens last performs the move.
  bool _mapReady = false;
  bool _centered = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _recenterZoom,
      );
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

    // A position, or courts, resolving after the map has been laid out.
    ref.listen(userPositionProvider, (previous, next) => _centerIfNeeded());
    ref.listen(nearbyCourtsProvider, (previous, next) => _centerIfNeeded());

    final courts = courtsAsync.value ?? const <CourtWithDistance>[];

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
            ),
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
                      width: 48,
                      height: 48,
                      child: CourtMarker(
                        selected:
                            _selected?.court.id == courtWithDistance.court.id,
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
            left: AppSpacing.lg,
            // Clears the recenter FAB (56dp) pinned to the same corner.
            right: AppSpacing.lg + 56 + AppSpacing.md,
            child: _MapStatusBanner(courtsAsync: courtsAsync),
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
  const _MapStatusBanner({required this.courtsAsync});

  final AsyncValue<List<CourtWithDistance>> courtsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (courtsAsync) {
      AsyncLoading() => const _BannerCard(
        icon: Icons.my_location,
        message: AppStrings.mapLocatingYou,
        showProgress: true,
      ),
      AsyncError(:final error) => _BannerCard(
        icon: courtErrorIcon(error),
        message: courtErrorMessage(error),
        actionLabel: AppStrings.retry,
        onAction: () => ref.invalidate(nearbyCourtsProvider),
      ),
      AsyncData(value: final courts) when courts.isEmpty => _BannerCard(
        icon: Icons.sports_basketball_outlined,
        message: AppStrings.noCourtsNearbyMapMessage,
        actionLabel: AppStrings.refresh,
        onAction: () => ref.invalidate(nearbyCourtsProvider),
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
