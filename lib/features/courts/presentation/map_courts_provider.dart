import 'package:flutter_riverpod/flutter_riverpod.dart';
// StreamProviderFamily, the declared type of courtsInBoundsProvider, lives
// outside the package's default export.
import 'package:flutter_riverpod/misc.dart';

import '../../../core/location/location_providers.dart';
import '../data/court_repository_provider.dart';
import '../domain/court_with_distance.dart';
import '../domain/geo_bounds.dart';

/// The box the map is currently showing, or null while the user hasn't moved
/// it themselves.
///
/// Null is what keeps the map on the same 5 km search as the list until the
/// user actually pans: the map is laid out (and reports a viewport) well
/// before the position fix lands, and honouring that first viewport would
/// spend an Overpass query on wherever the map happened to open.
class VisibleMapBoundsNotifier extends Notifier<GeoBounds?> {
  @override
  GeoBounds? build() => null;

  set bounds(GeoBounds value) => state = value;

  /// Hands the search back to the user's own surroundings, for when the map
  /// returns to them (the recenter button) rather than to a box they chose.
  void clear() => state = null;
}

final NotifierProvider<VisibleMapBoundsNotifier, GeoBounds?>
visibleMapBoundsProvider =
    NotifierProvider<VisibleMapBoundsNotifier, GeoBounds?>(
      VisibleMapBoundsNotifier.new,
    );

/// The courts inside an arbitrary box, nearest first.
///
/// Keyed by the box itself, so panning back to somewhere already searched is
/// answered from the family's cache instead of a second identical query, and
/// so a viewport that only jitters (the same box, recomputed) doesn't refetch
/// at all.
///
/// Distances are measured from the user when their position is known and from
/// the middle of the viewport otherwise — a court's distance has to be
/// measured from somewhere, and where the user is looking is the honest
/// fallback for where they are. The position is deliberately read rather than
/// watched: a fix landing mid-search would otherwise re-run the query purely
/// to relabel distances the next pan recomputes anyway.
///
/// Auto-retry is off for the same reason as the nearby-courts search: an
/// Overpass failure or a rate limit is not something to hammer on a loop.
final StreamProviderFamily<List<CourtWithDistance>, GeoBounds>
courtsInBoundsProvider =
    StreamProvider.family<List<CourtWithDistance>, GeoBounds>(
      (ref, bounds) async* {
        final courtRepository = ref.watch(courtRepositoryProvider);
        final position = ref.read(userPositionProvider).value;
        final originLat = position?.latitude ?? bounds.centerLat;
        final originLng = position?.longitude ?? bounds.centerLng;

        await for (final courts in courtRepository.watchCourtsInBounds(
          bounds,
        )) {
          yield courtsByDistanceFrom(courts, originLat, originLng);
        }
      },
      isAutoDispose: true,
      retry: (retryCount, error) => null,
    );
