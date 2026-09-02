import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_providers.dart';
import '../data/court_repository_provider.dart';
import '../domain/court_with_distance.dart';
import '../domain/geo_bounds.dart';

/// Radius of the search area used to look up nearby courts, in meters.
const double nearbyRadiusInMeters = 5000;

class NearbyCourtsNotifier extends StreamNotifier<List<CourtWithDistance>> {
  @override
  Stream<List<CourtWithDistance>> build() async* {
    final position = await ref.watch(userPositionProvider.future);
    final courtRepository = ref.watch(courtRepositoryProvider);
    final bounds = GeoBounds.aroundPoint(
      position.latitude,
      position.longitude,
      nearbyRadiusInMeters,
    );

    await for (final courts in courtRepository.watchCourtsInBounds(bounds)) {
      yield courtsByDistanceFrom(courts, position.latitude, position.longitude);
    }
  }
}

final StreamNotifierProvider<NearbyCourtsNotifier, List<CourtWithDistance>>
nearbyCourtsProvider =
    StreamNotifierProvider<NearbyCourtsNotifier, List<CourtWithDistance>>(
      NearbyCourtsNotifier.new,
      retry: (retryCount, error) => null,
    );
