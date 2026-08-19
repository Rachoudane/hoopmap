import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_providers.dart';
import '../data/court_repository_provider.dart';
import '../domain/court_with_distance.dart';
import '../domain/distance.dart';
import '../domain/geo_bounds.dart';

// Radius of the search area used to look up nearby courts, in meters.
const double _nearbyRadiusInMeters = 5000;

class NearbyCourtsNotifier extends StreamNotifier<List<CourtWithDistance>> {
  @override
  Stream<List<CourtWithDistance>> build() async* {
    final position = await ref.watch(locationServiceProvider).currentPosition();
    final courtRepository = ref.watch(courtRepositoryProvider);
    final bounds = GeoBounds.aroundPoint(
      position.latitude,
      position.longitude,
      _nearbyRadiusInMeters,
    );

    await for (final courts in courtRepository.watchCourtsInBounds(bounds)) {
      final courtsWithDistance =
          courts
              .map(
                (court) => CourtWithDistance(
                  court: court,
                  distanceInMeters: distanceInMetersBetween(
                    position.latitude,
                    position.longitude,
                    court.latitude,
                    court.longitude,
                  ),
                ),
              )
              .toList()
            ..sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));

      yield courtsWithDistance;
    }
  }
}

final StreamNotifierProvider<NearbyCourtsNotifier, List<CourtWithDistance>>
nearbyCourtsProvider =
    StreamNotifierProvider<NearbyCourtsNotifier, List<CourtWithDistance>>(
      NearbyCourtsNotifier.new,
      retry: (retryCount, error) => null,
    );
