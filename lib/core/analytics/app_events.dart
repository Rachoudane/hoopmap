import 'analytics_event.dart';

/// The fifteen events Hoopmap sends, and the whole of them.
///
/// Fifteen because the number is a budget, not a coincidence. An analytics
/// set that grows one event per feature stops answering anything: every
/// question takes a query nobody writes, and the funnel that actually matters
/// is buried among taps. So this catalogue covers one loop — arrive, be
/// located, search, open a court, go play — plus the contribution loop that
/// hangs off an empty result, and nothing else. Adding a sixteenth means
/// deciding which of these fifteen stopped earning its place; the test in
/// `test/core/analytics/app_events_test.dart` is there to make that a
/// decision rather than an accident.
///
/// Events are built here rather than at the call sites so no screen writes an
/// event name or a parameter key by hand — a typo in either is invisible
/// until someone reads an empty chart weeks later.
abstract final class AppEvents {
  static const String _onboardingCompleted = 'onboarding_completed';
  static const String _locationRationaleShown = 'location_rationale_shown';
  static const String _locationOptIn = 'location_opt_in';
  static const String _locationDeclined = 'location_declined';
  static const String _locationOutcome = 'location_outcome';
  static const String _courtsSearched = 'courts_searched';
  static const String _courtsSearchFailed = 'courts_search_failed';
  static const String _cityPicked = 'city_picked';
  static const String _courtOpened = 'court_opened';
  static const String _directionsOpened = 'directions_opened';
  static const String _mapRecentered = 'map_recentered';
  static const String _addCourtStarted = 'add_court_started';
  static const String _addCourtSubmitted = 'add_court_submitted';
  static const String _addCourtFailed = 'add_court_failed';
  static const String _courtReported = 'court_reported';

  /// Every name this app is allowed to send.
  static const List<String> catalogue = <String>[
    _onboardingCompleted,
    _locationRationaleShown,
    _locationOptIn,
    _locationDeclined,
    _locationOutcome,
    _courtsSearched,
    _courtsSearchFailed,
    _cityPicked,
    _courtOpened,
    _directionsOpened,
    _mapRecentered,
    _addCourtStarted,
    _addCourtSubmitted,
    _addCourtFailed,
    _courtReported,
  ];

  /// Onboarding was left, one way or another. [exit] is the fork: only
  /// "See courts near me" opts into a location.
  static AnalyticsEvent onboardingCompleted(OnboardingExit exit) =>
      AnalyticsEvent(_onboardingCompleted, {'exit': _snake(exit.name)});

  /// The explanation screen was shown, which is the denominator for
  /// [locationOptIn] and [locationDeclined]: how many people the app asked,
  /// against how many said yes.
  static AnalyticsEvent locationRationaleShown() =>
      const AnalyticsEvent(_locationRationaleShown);

  /// The user asked the app to use their location. The system dialog follows
  /// from here, so this is the last number the app itself controls.
  static AnalyticsEvent locationOptIn(LocationEntryPoint entryPoint) =>
      AnalyticsEvent(_locationOptIn, {'entry_point': _snake(entryPoint.name)});

  /// "Not now" on the explanation screen — a refusal the app can ask about
  /// again, unlike the system's.
  static AnalyticsEvent locationDeclined() =>
      const AnalyticsEvent(_locationDeclined);

  /// What actually came back once the system had its say: the permission, the
  /// location services switch, and a fix that may never arrive are three
  /// different ways to end up with no position, and only this tells them
  /// apart.
  static AnalyticsEvent locationOutcome(LocationOutcome outcome) =>
      AnalyticsEvent(_locationOutcome, {'outcome': _snake(outcome.name)});

  /// A search answered. [resultCount] is what says whether the app is useful
  /// where people actually are — an area with no courts is the single most
  /// common way Hoopmap disappoints.
  static AnalyticsEvent courtsSearched({
    required CourtSearchArea area,
    required int resultCount,
  }) => AnalyticsEvent(_courtsSearched, {
    'area': _snake(area.name),
    'result_count': resultCount,
  });

  /// A search that never answered. [reason] is the failure family the user
  /// was shown, so this counts the failures crash reporting deliberately
  /// ignores — an offline phone is not a bug, but it is a number worth
  /// having.
  static AnalyticsEvent courtsSearchFailed({
    required CourtSearchArea area,
    required String reason,
  }) => AnalyticsEvent(_courtsSearchFailed, {
    'area': _snake(area.name),
    'reason': reason,
  });

  /// A city was chosen from the bundled list — both a use of the no-location
  /// path and a vote for which cities the list is missing.
  static AnalyticsEvent cityPicked(String cityId) =>
      AnalyticsEvent(_cityPicked, {'city_id': cityId});

  static AnalyticsEvent courtOpened(CourtOrigin origin) =>
      AnalyticsEvent(_courtOpened, {'origin': _snake(origin.name)});

  /// The end of the loop: someone is going to a court.
  static AnalyticsEvent directionsOpened(CourtOrigin origin) =>
      AnalyticsEvent(_directionsOpened, {'origin': _snake(origin.name)});

  static AnalyticsEvent mapRecentered() => const AnalyticsEvent(_mapRecentered);

  static AnalyticsEvent addCourtStarted(AddCourtEntryPoint entryPoint) =>
      AnalyticsEvent(_addCourtStarted, {
        'entry_point': _snake(entryPoint.name),
      });

  static AnalyticsEvent addCourtSubmitted({
    required int hoopCount,
    required bool isOutdoor,
  }) => AnalyticsEvent(_addCourtSubmitted, {
    'hoop_count': hoopCount,
    'kind': isOutdoor ? 'outdoor' : 'indoor',
  });

  /// A submission that was refused or failed to write. Paired with
  /// [addCourtSubmitted], this is the completion rate of the only form in
  /// the app.
  static AnalyticsEvent addCourtFailed(String reason) =>
      AnalyticsEvent(_addCourtFailed, {'reason': reason});

  static AnalyticsEvent courtReported(String reason) =>
      AnalyticsEvent(_courtReported, {'reason': reason});

  /// Dart enum names are camelCase and Firebase groups values by exact
  /// string, so `deniedForever` and `denied_forever` would be two rows in a
  /// dashboard whose every other value is snake_case.
  static String _snake(String enumName) => enumName.replaceAllMapped(
    RegExp('[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );
}
