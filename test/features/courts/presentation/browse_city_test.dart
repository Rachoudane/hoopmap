import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/location/location_opt_in.dart';
import 'package:hoopmap/core/location/pages/location_rationale_page.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:hoopmap/features/courts/domain/city.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:hoopmap/features/courts/presentation/browse_city_provider.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_list_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/pick_city_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the box it was asked about, so a test can tell where the app
/// went looking.
class _RecordingCourtRepository implements CourtRepository {
  final List<GeoBounds> requestedBounds = [];

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) async* {
    requestedBounds.add(bounds);
    yield const [];
  }

  @override
  Stream<Court> watchCourt(String id) => Stream.error(UnimplementedError());

  @override
  Future<String> addCourt(Court court) => throw UnimplementedError();
}

Future<ProviderContainer> _container({
  Map<String, Object> initialPreferences = const {},
  CourtRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_completed': true,
    ...initialPreferences,
  });
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      if (repository != null)
        courtRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpList(WidgetTester tester, ProviderContainer container) async {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const CourtsListPage(),
      ),
      GoRoute(
        path: Routes.pickCity,
        name: Routes.pickCityName,
        builder: (context, state) => const PickCityPage(),
      ),
      GoRoute(
        path: Routes.locationRationale,
        name: Routes.locationRationaleName,
        builder: (context, state) => const LocationRationalePage(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

void main() {
  group('searchCities', () {
    test('an empty query offers the whole list', () {
      expect(searchCities(''), browsableCities);
      expect(searchCities('   '), browsableCities);
    });

    test('matches on the city name, whatever the case', () {
      expect(searchCities('lyon').map((c) => c.name), ['Lyon']);
      expect(searchCities('LYON').map((c) => c.name), ['Lyon']);
    });

    test('matches on the country too, so a short list stays usable', () {
      final spanish = searchCities('Spain').map((c) => c.name).toList();

      // Someone whose own town isn't offered can still find the nearest
      // city that is.
      expect(spanish, contains('Madrid'));
      expect(spanish, contains('Barcelona'));
    });

    test('an unmatched query comes back empty rather than guessing', () {
      expect(searchCities('Atlantis'), isEmpty);
    });
  });

  group('browseCityProvider', () {
    test('starts unset: the app looks from wherever the user is', () async {
      final container = await _container();

      expect(container.read(browseCityProvider), isNull);
    });

    test('remembers the chosen city across launches', () async {
      final container = await _container();
      final lyon = browsableCities.firstWhere((c) => c.name == 'Lyon');

      await container.read(browseCityProvider.notifier).choose(lyon);

      expect(container.read(browseCityProvider), lyon);

      // A user with no location should not have to re-pick their city every
      // time they open the app.
      final relaunched = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(relaunched.dispose);
      expect(relaunched.read(browseCityProvider), lyon);
    });

    test('clear() hands the search back to the user', () async {
      final container = await _container();
      final lyon = browsableCities.firstWhere((c) => c.name == 'Lyon');

      await container.read(browseCityProvider.notifier).choose(lyon);
      await container.read(browseCityProvider.notifier).clear();

      expect(container.read(browseCityProvider), isNull);
    });

    test('a stored city that no longer exists resolves to none', () async {
      final container = await _container(
        initialPreferences: {'browse_city': 'Atlantis, Nowhere'},
      );

      // Better to fall back to the user's own position than to open on
      // coordinates nothing in the app can explain.
      expect(container.read(browseCityProvider), isNull);
    });
  });

  group('a chosen city drives the search', () {
    test(
      'courts are looked for around the city, not around the user',
      () async {
        final repository = _RecordingCourtRepository();
        final container = await _container(repository: repository);
        final tokyo = browsableCities.firstWhere((c) => c.name == 'Tokyo');
        await container.read(browseCityProvider.notifier).choose(tokyo);
        container.listen(nearbyCourtsProvider, (previous, next) {});

        await container.read(nearbyCourtsProvider.future);

        expect(repository.requestedBounds, hasLength(1));
        expect(
          repository.requestedBounds.single.centerLat,
          closeTo(35.6762, 0.01),
        );
        expect(
          repository.requestedBounds.single.centerLng,
          closeTo(139.6503, 0.01),
        );
      },
    );

    test('and the location is never asked for', () async {
      final repository = _RecordingCourtRepository();
      final container = await _container(repository: repository);
      final tokyo = browsableCities.firstWhere((c) => c.name == 'Tokyo');
      await container.read(browseCityProvider.notifier).choose(tokyo);
      container.listen(nearbyCourtsProvider, (previous, next) {});

      await container.read(nearbyCourtsProvider.future);

      // Browsing Tokyo cannot depend on Hoopmap knowing where you are.
      expect(container.read(locationOptInProvider), isFalse);
    });
  });

  group('picking a city from the list', () {
    testWidgets('the offer to share a location also offers a city', (
      tester,
    ) async {
      final container = await _container(
        repository: _RecordingCourtRepository(),
      );
      await _pumpList(tester, container);

      expect(find.text(AppStrings.locationNotRequestedTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.browseACity));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.pickCityTitle), findsOneWidget);
    });

    testWidgets('choosing one titles the list with it and comes back', (
      tester,
    ) async {
      final container = await _container(
        repository: _RecordingCourtRepository(),
      );
      await _pumpList(tester, container);

      await tester.tap(find.text(AppStrings.browseACity));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lyon'));
      await tester.pumpAndSettle();

      expect(find.byType(PickCityPage), findsNothing);
      expect(find.text(AppStrings.browsingCity('Lyon')), findsOneWidget);
      expect(container.read(browseCityProvider)?.name, 'Lyon');
    });

    testWidgets('searching narrows the list', (tester) async {
      final container = await _container(
        repository: _RecordingCourtRepository(),
      );
      await _pumpList(tester, container);

      await tester.tap(find.text(AppStrings.browseACity));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Madrid');
      await tester.pumpAndSettle();

      // Scoped to the rows: the search field itself now reads "Madrid" too.
      expect(find.widgetWithText(ListTile, 'Madrid'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Lyon'), findsNothing);
    });

    testWidgets('"Use my location" drops the city and asks for the position', (
      tester,
    ) async {
      final container = await _container(
        initialPreferences: {'browse_city': 'Lyon, France'},
        repository: _RecordingCourtRepository(),
      );
      await _pumpList(tester, container);

      expect(find.text(AppStrings.browsingCity('Lyon')), findsOneWidget);

      await tester.tap(find.byTooltip(AppStrings.browseACity));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.pickCityUseMyLocation));
      await tester.pumpAndSettle();

      expect(container.read(browseCityProvider), isNull);
      // Coming back to "near me" is a location request like any other, so it
      // goes through the same explanation.
      expect(find.text(AppStrings.locationRationaleTitle), findsOneWidget);
    });
  });
}
