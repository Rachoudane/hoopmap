import 'dart:async';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/analytics/app_events.dart';
import '../../../core/location/location_service.dart';
import '../data/overpass_court_repository.dart';

/// Reports the outcome of one court search, whichever of the two search
/// paths ran it.
///
/// A search is a single question with a single answer, but it doesn't arrive
/// as one: [CompositeCourtRepository] emits once per source, so the same
/// search yields twice and counting every emission would double every number
/// in the dashboard. [found] therefore reports the first answer and ignores
/// the rest.
///
/// Created per search rather than shared, since its whole state is "has this
/// one already been counted".
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
