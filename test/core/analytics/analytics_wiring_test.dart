import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Override, the type of a ProviderScope's overrides, lives outside the
// package's default export.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/analytics/analytics_event.dart';
import 'package:hoopmap/core/analytics/analytics_providers.dart';
import 'package:hoopmap/core/analytics/analytics_service.dart';
import 'package:hoopmap/core/analytics/app_events.dart';
import 'package:hoopmap/core/auth/auth_providers.dart';
import 'package:hoopmap/core/location/location_opt_in.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/core/onboarding/pages/onboarding_page.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:hoopmap/core/settings/settings_providers.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:hoopmap/features/courts/data/overpass_court_repository.dart';
import 'package:hoopmap/features/courts/domain/city.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:hoopmap/features/courts/presentation/add_court_controller.dart';
import 'package:hoopmap/features/courts/presentation/browse_city_provider.dart';
import 'package:hoopmap/features/courts/presentation/add_court_flow.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingAnalyticsService implements AnalyticsService {
  final List<AnalyticsEvent> logged = <AnalyticsEvent>[];

  /// The names logged, for the assertions that are about what was counted
  /// and in which order rather than about the parameters.
  List<String> get names => logged.map((event) => event.name).toList();

  /// Just the events called [name], for assertions about one step of a flow
  /// that legitimately reports more than one thing.
  List<AnalyticsEvent> only(String name) =>
      logged.where((event) => event.name == name).toList();

  @override
  Future<void> log(AnalyticsEvent event) async => logged.add(event);

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}

class _FakeLocationService extends LocationService {
  _FakeLocationService.position(this._position) : _error = null;
  _FakeLocationService.throwing(this._error) : _position = null;

  final UserPosition? _position;
  final Object? _error;

  @override
  Future<bool> isServiceEnabled() async {
    // The service check runs first in currentPosition(), so a fake that only
    // threw from readPosition() could never reproduce a disabled-GPS failure.
    final error = _error;
    if (error != null) throw error;
    return true;
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<UserPosition> readPosition() async {
    final error = _error;
    if (error != null) throw error;
    return _position!;
  }

  @override
  Future<UserPosition?> lastKnownPosition() async => null;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _FakeCourtRepository implements CourtRepository {
  _FakeCourtRepository(this._courts, {this.error});

  final Stream<List<Court>> _courts;
  final Object? error;

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) {
    final failure = error;
    if (failure != null) return Stream<List<Court>>.error(failure);
    return _courts;
  }

  @override
  Stream<Court> watchCourt(String id) => Stream.error(UnimplementedError());

  @override
  Future<String> addCourt(Court court) async => 'new-court';
}

class _RefusingCourtRepository implements CourtRepository {
  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) =>
      const Stream.empty();

  @override
  Stream<Court> watchCourt(String id) => Stream.error(UnimplementedError());

  @override
  Future<String> addCourt(Court court) async =>
      throw OverpassException('the write was refused');
}

Court _court(String id) => Court(
  id: id,
  name: 'Court $id',
  latitude: 48.8566,
  longitude: 2.3522,
  hoopCount: 2,
  isOutdoor: true,
  createdAt: DateTime(2026),
);

/// A user browsing from their own position: opted in, no city picked, the
/// shipped radius. Each of those gates has its own test elsewhere; these
/// start where a user who pressed "See courts near me" starts.
List<Override> _browsingFromPosition({
  required CourtRepository repository,
  required AnalyticsService analytics,
  LocationService? locationService,
  City? city,
}) => [
  analyticsProvider.overrideWithValue(analytics),
  locationOptInProvider.overrideWithBuild((ref, notifier) => true),
  browseCityProvider.overrideWithBuild((ref, notifier) => city),
  searchRadiusProvider.overrideWithBuild(
    (ref, notifier) => defaultSearchRadiusInMeters,
  ),
  courtRepositoryProvider.overrideWithValue(repository),
  locationServiceProvider.overrideWithValue(
    locationService ??
        _FakeLocationService.position(
          const UserPosition(latitude: 48.8566, longitude: 2.3522),
        ),
  ),
];

Future<ProviderContainer> _preferencesContainer(
  RecordingAnalyticsService analytics, {
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      analyticsProvider.overrideWithValue(analytics),
      ...overrides,
    ],
  );
}

/// Pumps [page] with [analytics] wired and onboarding already done, on a
/// router with a stub for every route the flows under test push to.
Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required RecordingAnalyticsService analytics,
  required SharedPreferences preferences,
  String initialLocation = Routes.home,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => page),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: Routes.termsAccept,
        name: Routes.termsAcceptName,
        builder: (context, state) => const Scaffold(body: Text('terms')),
      ),
      GoRoute(
        path: Routes.addCourt,
        name: Routes.addCourtName,
        builder: (context, state) => const Scaffold(body: Text('form')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        analyticsProvider.overrideWithValue(analytics),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('leaving onboarding', () {
    testWidgets('Skip and "See courts near me" are not the same exit', (
      tester,
    ) async {
      for (final scenario in <(String, OnboardingExit, bool)>[
        (AppStrings.onboardingSkip, OnboardingExit.skipped, false),
        (
          AppStrings.onboardingBrowseInstead,
          OnboardingExit.browseInstead,
          false,
        ),
        (AppStrings.onboardingGetStarted, OnboardingExit.getStarted, true),
      ]) {
        final (label, exit, optsIn) = scenario;
        final analytics = RecordingAnalyticsService();
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();

        await _pump(
          tester,
          const SizedBox.shrink(),
          analytics: analytics,
          preferences: preferences,
          initialLocation: '/onboarding',
        );

        // The last slide carries two of the three buttons.
        if (label != AppStrings.onboardingSkip) {
          await tester.tap(find.text(AppStrings.onboardingNext));
          await tester.pumpAndSettle();
          await tester.tap(find.text(AppStrings.onboardingNext));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        // Three ways out of the same screen, and only one of them is the
        // app being given a location — a single "onboarding done" count
        // would say nothing about which.
        expect(analytics.only('onboarding_completed'), [
          AppEvents.onboardingCompleted(exit),
        ], reason: label);
        expect(
          analytics.only('location_opt_in'),
          optsIn
              ? [AppEvents.locationOptIn(LocationEntryPoint.onboarding)]
              : isEmpty,
          reason: label,
        );
      }
    });
  });

  group('opening the add-court form', () {
    testWidgets('says which door it came through', (tester) async {
      for (final entryPoint in AddCourtEntryPoint.values) {
        final analytics = RecordingAnalyticsService();
        SharedPreferences.setMockInitialValues({
          'onboarding_completed': true,
          'terms_of_use_accepted': true,
        });
        final preferences = await SharedPreferences.getInstance();

        await _pump(
          tester,
          Consumer(
            builder: (context, ref, child) => Scaffold(
              body: TextButton(
                onPressed: () => openAddCourtFlow(context, ref, entryPoint),
                child: const Text('open'),
              ),
            ),
          ),
          analytics: analytics,
          preferences: preferences,
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Counted in the flow rather than at each button, because that is
        // also where the Terms gate lives: a new door cannot appear without
        // passing through both.
        expect(analytics.logged, [
          AppEvents.addCourtStarted(entryPoint),
        ], reason: '$entryPoint');
      }
    });
  });

  group('the location funnel', () {
    test('an opt-in is counted, and says which screen asked', () async {
      final analytics = RecordingAnalyticsService();
      final container = await _preferencesContainer(analytics);
      addTearDown(container.dispose);

      await container
          .read(locationOptInProvider.notifier)
          .optIn(LocationEntryPoint.onboarding);

      expect(analytics.logged, [
        AppEvents.locationOptIn(LocationEntryPoint.onboarding),
      ]);
    });

    test('a position that arrives is counted as granted', () async {
      final analytics = RecordingAnalyticsService();
      final container = await _preferencesContainer(
        analytics,
        overrides: [
          locationOptInProvider.overrideWithBuild((ref, notifier) => true),
          locationServiceProvider.overrideWithValue(
            _FakeLocationService.position(
              const UserPosition(latitude: 1, longitude: 2),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(userPositionProvider.future);

      expect(analytics.logged, [
        AppEvents.locationOutcome(LocationOutcome.granted),
      ]);
    });

    test('the ways to end up with no position are told apart', () async {
      const failures = <Object, LocationOutcome>{
        LocationPermissionPermanentlyDeniedException():
            LocationOutcome.deniedForever,
        LocationServiceDisabledException(): LocationOutcome.serviceOff,
        LocationFixTimeoutException(): LocationOutcome.fixTimedOut,
      };

      for (final entry in failures.entries) {
        final analytics = RecordingAnalyticsService();
        final container = await _preferencesContainer(
          analytics,
          overrides: [
            locationOptInProvider.overrideWithBuild((ref, notifier) => true),
            locationServiceProvider.overrideWithValue(
              _FakeLocationService.throwing(entry.key),
            ),
          ],
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(userPositionProvider.future),
          throwsA(entry.key),
        );

        // One number for "asked and got nothing" would hide the difference
        // between a setting to fix and a fix that never came.
        expect(analytics.logged, [
          AppEvents.locationOutcome(entry.value),
        ], reason: '${entry.key}');
      }
    });

    test('nothing is counted before the user has asked', () async {
      final analytics = RecordingAnalyticsService();
      final container = await _preferencesContainer(
        analytics,
        overrides: [
          locationServiceProvider.overrideWithValue(
            _FakeLocationService.position(
              const UserPosition(latitude: 1, longitude: 2),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(userPositionProvider.future),
        throwsA(isA<LocationNotRequestedException>()),
      );

      // Not an outcome: the system was never asked, so there is nothing to
      // attribute to it.
      expect(analytics.logged, isEmpty);
    });
  });

  group('searches', () {
    test('one search is counted once, however many values follow', () async {
      final analytics = RecordingAnalyticsService();
      final courts = StreamController<List<Court>>();
      addTearDown(courts.close);
      final container = ProviderContainer(
        overrides: _browsingFromPosition(
          repository: _FakeCourtRepository(courts.stream),
          analytics: analytics,
        ),
      );
      final subscription = container.listen(
        nearbyCourtsProvider,
        (previous, next) {},
      );

      // The repository answers once, completely; a later value is a live
      // update to a search already counted, not the same search answering
      // twice.
      courts.add([_court('osm:way-1')]);
      await container.read(nearbyCourtsProvider.future);
      courts.add([_court('osm:way-1'), _court('firestore-1')]);
      await Future<void>.delayed(Duration.zero);

      subscription.close();
      container.dispose();

      expect(analytics.only('courts_searched'), [
        AppEvents.courtsSearched(
          area: CourtSearchArea.position,
          resultCount: 1,
        ),
      ]);
    });

    test('a search around a picked city says so', () async {
      final analytics = RecordingAnalyticsService();
      final container = ProviderContainer(
        overrides: _browsingFromPosition(
          repository: _FakeCourtRepository(
            Stream.value(<Court>[_court('osm:way-1')]),
          ),
          analytics: analytics,
          city: browsableCities.first,
        ),
      );
      final subscription = container.listen(
        nearbyCourtsProvider,
        (previous, next) {},
      );

      await container.read(nearbyCourtsProvider.future);
      subscription.close();
      container.dispose();

      // No position was ever read, so nothing but the search is reported:
      // browsing Tokyo does not depend on Hoopmap knowing where you are.
      expect(analytics.logged, [
        AppEvents.courtsSearched(area: CourtSearchArea.city, resultCount: 1),
      ]);
    });

    test('a failed search is counted with the reason the user saw', () async {
      final analytics = RecordingAnalyticsService();
      final container = ProviderContainer(
        overrides: _browsingFromPosition(
          repository: _FakeCourtRepository(
            const Stream.empty(),
            error: const NetworkUnavailableException(),
          ),
          analytics: analytics,
        ),
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        nearbyCourtsProvider,
        (previous, next) {},
      );
      addTearDown(subscription.close);

      await expectLater(
        container.read(nearbyCourtsProvider.future),
        throwsA(isA<NetworkUnavailableException>()),
      );

      expect(analytics.only('courts_search_failed'), [
        AppEvents.courtsSearchFailed(
          area: CourtSearchArea.position,
          reason: 'offline',
        ),
      ]);
    });

    test('a search that never found a position also failed', () async {
      final analytics = RecordingAnalyticsService();
      final container = ProviderContainer(
        overrides: _browsingFromPosition(
          repository: _FakeCourtRepository(const Stream.empty()),
          analytics: analytics,
          locationService: _FakeLocationService.throwing(
            const LocationServiceDisabledException(),
          ),
        ),
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        nearbyCourtsProvider,
        (previous, next) {},
      );
      addTearDown(subscription.close);

      await expectLater(
        container.read(nearbyCourtsProvider.future),
        throwsA(isA<LocationServiceDisabledException>()),
      );

      // Two events, and both are true: the system said no, and the search
      // the user actually asked for never happened.
      expect(analytics.names, ['location_outcome', 'courts_search_failed']);
      expect(
        analytics.logged.last,
        AppEvents.courtsSearchFailed(
          area: CourtSearchArea.position,
          reason: 'location_service_off',
        ),
      );
    });
  });

  group('picking a city', () {
    test('is counted with the city, not just the fact', () async {
      final analytics = RecordingAnalyticsService();
      final container = await _preferencesContainer(analytics);
      addTearDown(container.dispose);

      final city = browsableCities.first;
      await container.read(browseCityProvider.notifier).choose(city);

      expect(analytics.logged, [AppEvents.cityPicked(city.id)]);
    });

    test('going back to "my location" is not a city being picked', () async {
      final analytics = RecordingAnalyticsService();
      final container = await _preferencesContainer(analytics);
      addTearDown(container.dispose);

      await container.read(browseCityProvider.notifier).clear();

      expect(analytics.logged, isEmpty);
    });
  });

  group('adding a court', () {
    ProviderContainer containerFor(
      CourtRepository repository,
      RecordingAnalyticsService analytics,
    ) {
      final container = ProviderContainer(
        overrides: [
          analyticsProvider.overrideWithValue(analytics),
          courtRepositoryProvider.overrideWithValue(repository),
          anonymousSessionProvider.overrideWith((ref) async => 'uid-1'),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('an accepted submission is counted with what it held', () async {
      final analytics = RecordingAnalyticsService();
      final container = containerFor(
        _FakeCourtRepository(const Stream.empty()),
        analytics,
      );

      await container
          .read(addCourtControllerProvider.notifier)
          .submit(
            name: 'Parc des Sports',
            hoopCount: 4,
            isOutdoor: false,
            latitude: 48.85,
            longitude: 2.35,
          );

      expect(analytics.logged, [
        AppEvents.addCourtSubmitted(hoopCount: 4, isOutdoor: false),
      ]);
    });

    test('a form filled in wrong is not a write that failed', () async {
      final analytics = RecordingAnalyticsService();
      final container = containerFor(
        _FakeCourtRepository(const Stream.empty()),
        analytics,
      );

      await container
          .read(addCourtControllerProvider.notifier)
          .submit(
            name: 'x',
            hoopCount: 4,
            isOutdoor: true,
            latitude: 48.85,
            longitude: 2.35,
          );

      // One is a label to fix, the other an outage. Counting them together
      // would make either invisible.
      expect(analytics.logged, [AppEvents.addCourtFailed('invalid_input')]);
    });

    test('a refused write is a failure, not a submission', () async {
      final analytics = RecordingAnalyticsService();
      final container = containerFor(_RefusingCourtRepository(), analytics);

      await container
          .read(addCourtControllerProvider.notifier)
          .submit(
            name: 'Parc des Sports',
            hoopCount: 4,
            isOutdoor: true,
            latitude: 48.85,
            longitude: 2.35,
          );

      expect(analytics.logged, [AppEvents.addCourtFailed('write_failed')]);
    });
  });

  group('opening a court', () {
    testWidgets('is counted once, deep links included', (tester) async {
      final analytics = RecordingAnalyticsService();
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final preferences = await SharedPreferences.getInstance();

      final router = GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) =>
                const CourtDetailPage(courtId: 'osm:way-42'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            analyticsProvider.overrideWithValue(analytics),
            courtRepositoryProvider.overrideWithValue(
              _FakeCourtRepository(const Stream.empty()),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      // Counted from the page rather than from the taps that lead to it, so
      // a cold deep link — which arrives with no tap anywhere in the app —
      // is counted like any other open.
      expect(analytics.logged, [
        AppEvents.courtOpened(CourtOrigin.openStreetMap),
      ]);

      // And rebuilding the page is not opening it again.
      await tester.pump();
      expect(analytics.logged, hasLength(1));
    });

    test('a court added here is told from one imported', () {
      expect(courtOriginOf('osm:way-42'), CourtOrigin.openStreetMap);
      expect(courtOriginOf('aBcDeF123'), CourtOrigin.hoopmap);
    });
  });

  group('the default', () {
    test('measures nothing until a composition root wires it', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final analytics = container.read(analyticsProvider);
      expect(analytics, isA<NoOpAnalyticsService>());
      // Nothing else to assert than that it neither throws nor needs a
      // Firebase app, which is the whole reason it is the default.
      await analytics.log(AppEvents.mapRecentered());
      await analytics.setCollectionEnabled(true);
    });
  });
}
