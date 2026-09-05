import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_providers.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/settings/settings_providers.dart';
import '../data/court_repository_provider.dart';
import '../domain/court_with_distance.dart';
import '../domain/geo_bounds.dart';
import 'browse_city_provider.dart';
import 'court_search_analytics.dart';

/// The courts around wherever the user is looking from: their own position,
/// or the city they picked instead.
class NearbyCourtsNotifier extends StreamNotifier<List<CourtWithDistance>> {
  @override
  Stream<List<CourtWithDistance>> build() async* {
    // A chosen city short-circuits the position entirely — not just its
    // value, but the whole permission question. Browsing Tokyo must not
    // depend on Hoopmap knowing where you are.
    final city = ref.watch(browseCityProvider);
    final report = CourtSearchReport(
      ref.watch(analyticsProvider),
      city == null ? CourtSearchArea.position : CourtSearchArea.city,
    );

    // The position fix is inside the reported span on purpose: to the user, a
    // search that never happened because the app couldn't locate them is a
    // search that failed.
    try {
      final double latitude;
      final double longitude;
      if (city != null) {
        latitude = city.latitude;
        longitude = city.longitude;
      } else {
        final position = await ref.watch(userPositionProvider.future);
        latitude = position.latitude;
        longitude = position.longitude;
      }

      final courtRepository = ref.watch(courtRepositoryProvider);
      final bounds = GeoBounds.aroundPoint(
        latitude,
        longitude,
        ref.watch(searchRadiusProvider),
      );

      await for (final courts in courtRepository.watchCourtsInBounds(bounds)) {
        report.found(courts.length);
        yield courtsByDistanceFrom(courts, latitude, longitude);
      }
    } catch (error) {
      report.failed(error);
      rethrow;
    }
  }
}

final StreamNotifierProvider<NearbyCourtsNotifier, List<CourtWithDistance>>
nearbyCourtsProvider =
    StreamNotifierProvider<NearbyCourtsNotifier, List<CourtWithDistance>>(
      NearbyCourtsNotifier.new,
      retry: (retryCount, error) => null,
    );
