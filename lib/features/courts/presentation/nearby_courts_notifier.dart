import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_providers.dart';
import '../data/court_repository_provider.dart';
import '../domain/court_with_distance.dart';
import '../domain/distance.dart';

class NearbyCourtsNotifier extends StreamNotifier<List<CourtWithDistance>> {
  @override
  Stream<List<CourtWithDistance>> build() async* {
    final position = await ref.watch(locationServiceProvider).currentPosition();
    final courtRepository = ref.watch(courtRepositoryProvider);

    await for (final courts in courtRepository.watchCourts()) {
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
