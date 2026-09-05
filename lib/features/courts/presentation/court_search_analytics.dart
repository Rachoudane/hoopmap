import 'dart:async';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/analytics/app_events.dart';
import '../../../core/location/location_service.dart';
import '../data/overpass_court_repository.dart';

/// Reports the outcome of one court search, whichever of the two search paths
/// ran it.
///
/// One search, one event. `CompositeCourtRepository` holds its first value
/// back until every source has answered, so that first value *is* the answer
/// and can simply be counted. Anything after it is a live update to a search
/// already reported — a court somebody added while the list was open — not
/// the same search answering twice.
///
/// Getting this wrong is not hypothetical: counting every emission would
/// double every number in the dashboard, and an earlier version that counted
/// the first of several partial emissions recorded `result_count: 0` for a
/// search that had found forty courts, while six of them were on screen.
///
/// Created per search, since its whole state is whether this one has been
/// counted.
class CourtSearchReport {
  CourtSearchReport(this._analytics, this._area);

  final AnalyticsService _analytics;
  final CourtSearchArea _area;
  bool _reported = false;

  void found(int resultCount) {
    if (_reported) return;
    _reported = true;
    unawaited(
      _analytics.log(
        AppEvents.courtsSearched(area: _area, resultCount: resultCount),
      ),
    );
  }

  void failed(Object error) {
    if (_reported) return;
    _reported = true;
    unawaited(
      _analytics.log(
        AppEvents.courtsSearchFailed(
          area: _area,
          reason: courtSearchFailureReason(error),
        ),
      ),
    );
  }
}

/// The failure family behind [error], in the same terms the user was shown.
///
/// These are the failures crash reporting deliberately ignores — an offline
/// phone or an Overpass instance that is down is not a bug. It is still worth
/// counting: how often the app fails to answer at all, and for which of the
/// reasons, is the difference between a service problem and a product one.
String courtSearchFailureReason(Object error) => switch (error) {
  LocationNotRequestedException() => 'location_not_requested',
  LocationPermissionPermanentlyDeniedException() => 'location_denied_forever',
  LocationPermissionDeniedException() => 'location_denied',
  LocationServiceDisabledException() => 'location_service_off',
  LocationFixTimeoutException() => 'location_timed_out',
  NetworkUnavailableException() => 'offline',
  OverpassRateLimitedException() => 'rate_limited',
  AreaTooLargeException() => 'area_too_large',
  OverpassException() => 'overpass_failed',
  _ => 'unknown',
};
