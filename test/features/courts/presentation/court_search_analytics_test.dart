import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/analytics/analytics_event.dart';
import 'package:hoopmap/core/analytics/app_events.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/features/courts/data/overpass_court_repository.dart';
import 'package:hoopmap/features/courts/presentation/court_search_analytics.dart';

import '../../../core/analytics/analytics_wiring_test.dart'
    show RecordingAnalyticsService;

void main() {
  group('CourtSearchReport', () {
    test('counts the answer the repository settled on', () {
      final analytics = RecordingAnalyticsService();
      final report = CourtSearchReport(analytics, CourtSearchArea.position);

      report.found(40);

      expect(analytics.logged, [
        AppEvents.courtsSearched(
          area: CourtSearchArea.position,
          resultCount: 40,
        ),
      ]);
    });

    test('a genuinely empty area is still reported as empty', () {
      final analytics = RecordingAnalyticsService();
      final report = CourtSearchReport(analytics, CourtSearchArea.mapBounds);

      report.found(0);

      expect(analytics.logged, [
        AppEvents.courtsSearched(
          area: CourtSearchArea.mapBounds,
          resultCount: 0,
        ),
      ]);
    });

    test('a live update is not a second search', () {
      final analytics = RecordingAnalyticsService();
      final report = CourtSearchReport(analytics, CourtSearchArea.position);

      report.found(5);
      // Somebody added a court while the list was open. The search that was
      // asked has already been answered and counted.
      report.found(6);

      expect(analytics.logged, [
        AppEvents.courtsSearched(
          area: CourtSearchArea.position,
          resultCount: 5,
        ),
      ]);
    });

    test('a failure is reported with the reason the user saw', () {
      final analytics = RecordingAnalyticsService();
      final report = CourtSearchReport(analytics, CourtSearchArea.position);

      report.failed(const NetworkUnavailableException());

      expect(analytics.logged, [
        AppEvents.courtsSearchFailed(
          area: CourtSearchArea.position,
          reason: 'offline',
        ),
      ]);
    });

    test('a search is either answered or failed, never both', () {
      final analytics = RecordingAnalyticsService();
      final report = CourtSearchReport(analytics, CourtSearchArea.position);

      report.found(4);
      report.failed(OverpassRateLimitedException());

      expect(analytics.names, ['courts_searched']);
    });
  });

  group('courtSearchFailureReason', () {
    test('names every failure the app has a screen for', () {
      expect(
        courtSearchFailureReason(const LocationNotRequestedException()),
        'location_not_requested',
      );
      expect(
        courtSearchFailureReason(
          const LocationPermissionPermanentlyDeniedException(),
        ),
        'location_denied_forever',
      );
      expect(
        courtSearchFailureReason(const LocationPermissionDeniedException()),
        'location_denied',
      );
      expect(
        courtSearchFailureReason(const LocationServiceDisabledException()),
        'location_service_off',
      );
      expect(
        courtSearchFailureReason(const LocationFixTimeoutException()),
        'location_timed_out',
      );
      expect(
        courtSearchFailureReason(const NetworkUnavailableException()),
        'offline',
      );
      expect(
        courtSearchFailureReason(OverpassRateLimitedException()),
        'rate_limited',
      );
      expect(
        courtSearchFailureReason(AreaTooLargeException(30)),
        'area_too_large',
      );
      expect(
        courtSearchFailureReason(OverpassException('down')),
        'overpass_failed',
      );
    });

    test('anything else is unknown rather than mislabelled', () {
      expect(courtSearchFailureReason(StateError('?')), 'unknown');
    });
  });
}
