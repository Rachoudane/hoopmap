import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/analytics/analytics_event.dart';
import 'package:hoopmap/core/analytics/app_events.dart';

/// One of every event the app can send, built with representative values.
///
/// Written out by hand rather than derived, because that is the point: the
/// list below and [AppEvents.catalogue] have to be kept in step by a person,
/// and the tests fail loudly when they aren't.
final List<AnalyticsEvent> _everyEvent = <AnalyticsEvent>[
  AppEvents.onboardingCompleted(OnboardingExit.getStarted),
  AppEvents.locationRationaleShown(),
  AppEvents.locationOptIn(LocationEntryPoint.onboarding),
  AppEvents.locationDeclined(),
  AppEvents.locationOutcome(LocationOutcome.deniedForever),
  AppEvents.courtsSearched(area: CourtSearchArea.mapBounds, resultCount: 3),
  AppEvents.courtsSearchFailed(
    area: CourtSearchArea.position,
    reason: 'offline',
  ),
  AppEvents.cityPicked('lyon'),
  AppEvents.courtOpened(CourtOrigin.openStreetMap),
  AppEvents.directionsOpened(CourtOrigin.hoopmap),
  AppEvents.mapRecentered(),
  AppEvents.addCourtStarted(AddCourtEntryPoint.listEmpty),
  AppEvents.addCourtSubmitted(hoopCount: 2, isOutdoor: true),
  AppEvents.addCourtFailed('write_failed'),
  AppEvents.courtReported('duplicate'),
];

// Firebase Analytics silently drops what it cannot store, so these limits are
// worth asserting rather than discovering from an empty dashboard.
final RegExp _eventName = RegExp(r'^[a-z][a-z0-9_]*$');
const int _maxNameLength = 40;
const int _maxStringValueLength = 100;
const int _maxParameters = 25;

// Names Firebase reserves for itself; logging one is rejected outright.
const Set<String> _reservedNames = {
  'app_clear_data',
  'app_exception',
  'app_remove',
  'app_update',
  'first_open',
  'first_visit',
  'in_app_purchase',
  'notification_dismiss',
  'notification_foreground',
  'notification_open',
  'notification_receive',
  'os_update',
  'session_start',
  'user_engagement',
};

void main() {
  group('the catalogue', () {
    test('holds exactly fifteen events, each named once', () {
      // The budget in the doc comment, made enforceable: a sixteenth event
      // has to be argued for here before it can be sent.
      expect(AppEvents.catalogue, hasLength(15));
      expect(AppEvents.catalogue.toSet(), hasLength(15));
    });

    test('every event the app builds is one of the fifteen', () {
      expect(_everyEvent, hasLength(15));
      expect(
        _everyEvent.map((event) => event.name).toSet(),
        AppEvents.catalogue.toSet(),
      );
    });
  });

  group('what Firebase will accept', () {
    test('every name is snake_case, short enough, and not reserved', () {
      for (final name in AppEvents.catalogue) {
        expect(name, matches(_eventName), reason: name);
        expect(name.length, lessThanOrEqualTo(_maxNameLength), reason: name);
        expect(_reservedNames, isNot(contains(name)), reason: name);
      }
    });

    test('every parameter is a key and a value Firebase can store', () {
      for (final event in _everyEvent) {
        expect(
          event.parameters,
          hasLength(lessThanOrEqualTo(_maxParameters)),
          reason: event.name,
        );
        event.parameters.forEach((key, value) {
          expect(key, matches(_eventName), reason: '${event.name}.$key');
          expect(
            key.length,
            lessThanOrEqualTo(_maxNameLength),
            reason: '${event.name}.$key',
          );
          // Firebase stores strings and numbers; a bool would arrive as
          // neither, which is why addCourtSubmitted spells one out.
          expect(
            value,
            anyOf(isA<String>(), isA<num>()),
            reason: '${event.name}.$key',
          );
          if (value is String) {
            expect(
              value.length,
              lessThanOrEqualTo(_maxStringValueLength),
              reason: '${event.name}.$key',
            );
          }
        });
      }
    });
  });

  group('parameter values', () {
    test('camelCase enum names arrive as snake_case', () {
      // `deniedForever` and `denied_forever` would be two rows in a dashboard
      // whose every other value is snake_case.
      expect(
        AppEvents.locationOutcome(LocationOutcome.deniedForever).parameters,
        {'outcome': 'denied_forever'},
      );
      expect(AppEvents.courtOpened(CourtOrigin.openStreetMap).parameters, {
        'origin': 'open_street_map',
      });
      expect(
        AppEvents.addCourtStarted(AddCourtEntryPoint.listEmpty).parameters,
        {'entry_point': 'list_empty'},
      );
    });

    test('a court is described as outdoor or indoor, never true or false', () {
      expect(
        AppEvents.addCourtSubmitted(hoopCount: 2, isOutdoor: true).parameters,
        {'hoop_count': 2, 'kind': 'outdoor'},
      );
      expect(
        AppEvents.addCourtSubmitted(hoopCount: 1, isOutdoor: false).parameters,
        {'hoop_count': 1, 'kind': 'indoor'},
      );
    });

    test('a search carries the area it covered and what it found', () {
      expect(
        AppEvents.courtsSearched(
          area: CourtSearchArea.mapBounds,
          resultCount: 0,
        ).parameters,
        {'area': 'map_bounds', 'result_count': 0},
      );
    });
  });

  group('AnalyticsEvent', () {
    test('compares by name and parameters, so a test can name one', () {
      expect(
        AppEvents.addCourtSubmitted(hoopCount: 2, isOutdoor: true),
        AppEvents.addCourtSubmitted(hoopCount: 2, isOutdoor: true),
      );
      expect(
        AppEvents.addCourtSubmitted(hoopCount: 2, isOutdoor: true),
        isNot(AppEvents.addCourtSubmitted(hoopCount: 3, isOutdoor: true)),
      );
      expect(
        AppEvents.locationOptIn(LocationEntryPoint.inApp),
        isNot(AppEvents.locationOptIn(LocationEntryPoint.onboarding)),
      );
      expect(AppEvents.mapRecentered(), isNot(AppEvents.locationDeclined()));
      expect(
        AppEvents.cityPicked('lyon').hashCode,
        AppEvents.cityPicked('lyon').hashCode,
      );
    });
  });
}
