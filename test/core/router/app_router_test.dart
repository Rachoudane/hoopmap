import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/core/onboarding/pages/onboarding_page.dart';
import 'package:hoopmap/core/presentation/pages/not_found_page.dart';
import 'package:hoopmap/core/router/app_router.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/presentation/court_detail_provider.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_list_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_map_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

final List<CourtWithDistance> _fixedCourts = [
  CourtWithDistance(
    court: Court(
      id: 'court-a',
      name: 'Court A',
      latitude: 0,
      longitude: 0,
      hoopCount: 1,
      isOutdoor: true,
      createdAt: DateTime(2026, 1, 1),
    ),
    distanceInMeters: 450,
  ),
];

// CourtDetailPage reads courtDetailProvider, which normally hits the real
// Overpass/Firestore repositories; these router tests only care about
// navigation, so the family is overridden wholesale with a fake court.
Court _fakeCourtDetail(String id) => Court(
  id: id,
  name: 'Court $id',
  latitude: 0,
  longitude: 0,
  hoopCount: 1,
  isOutdoor: true,
  createdAt: DateTime(2026, 1, 1),
);

Future<SharedPreferences> _onboardingCompletedPrefs() async {
  SharedPreferences.setMockInitialValues({'onboarding_completed': true});
  return SharedPreferences.getInstance();
}

Future<GoRouter> _pumpRouterApp(
  WidgetTester tester, {
  bool onboardingCompleted = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_completed': onboardingCompleted,
  });
  final sharedPreferences = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
        yield _fixedCourts;
      }),
      courtDetailProvider.overrideWith(
        (ref, id) => Stream.value(_fakeCourtDetail(id)),
      ),
    ],
  );
  addTearDown(container.dispose);
  final GoRouter router = container.read(goRouterProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return router;
}

// app_router.dart hardcodes initialLocation to Routes.home, so a cold start
// at a deep-linked location is exercised here by building an equivalent,
// simplified router directly with a custom initialLocation (home and court
// detail are both top-level routes in the real router too).
Future<GoRouter> _pumpRouterAppAt(
  WidgetTester tester,
  String initialLocation,
) async {
  final container = ProviderContainer(
    overrides: [
      nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
        yield _fixedCourts;
      }),
      courtDetailProvider.overrideWith(
        (ref, id) => Stream.value(_fakeCourtDetail(id)),
      ),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: Routes.home,
        name: Routes.homeName,
        builder: (context, state) => const CourtsListPage(),
      ),
      GoRoute(
        path: Routes.map,
        name: Routes.mapName,
        builder: (context, state) => const CourtsMapPage(),
      ),
      GoRoute(
        path: Routes.courtDetail,
        name: Routes.courtDetailName,
        builder: (context, state) {
          final courtId = state.pathParameters[Routes.courtIdParam]!;
          return CourtDetailPage(courtId: courtId);
        },
      ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return router;
}

void main() {
  testWidgets('resolves /courts/:id to CourtDetailPage with the given id', (
    tester,
  ) async {
    final router = await _pumpRouterApp(tester);

    router.go('/courts/abc123');
    await tester.pumpAndSettle();

    final detailPage = tester.widget<CourtDetailPage>(
      find.byType(CourtDetailPage),
    );
    expect(detailPage.courtId, 'abc123');
  });

  testWidgets(
    'resolves the hoopmap://courts/<id> deep link (host, not path) to '
    'CourtDetailPage',
    (tester) async {
      // Android's <data android:scheme="hoopmap" android:host="courts"/>
      // intent-filter delivers this as a URI with "courts" as the host,
      // not as part of the path (see app_router.dart's redirect) — found
      // by actually triggering the deep link on a device, where it fell
      // through to NotFoundPage instead of CourtDetailPage.
      final router = await _pumpRouterApp(tester);

      router.go('hoopmap://courts/abc123');
      await tester.pumpAndSettle();

      expect(find.byType(CourtDetailPage), findsOneWidget);
      final detailPage = tester.widget<CourtDetailPage>(
        find.byType(CourtDetailPage),
      );
      expect(detailPage.courtId, 'abc123');
    },
  );

  testWidgets('resolves an unknown URL to NotFoundPage', (tester) async {
    final router = await _pumpRouterApp(tester);

    router.go('/this/does/not/exist');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundPage), findsOneWidget);
  });

  testWidgets('popping from court detail returns to CourtsListPage', (
    tester,
  ) async {
    final router = await _pumpRouterApp(tester);

    // The app always reaches court detail via push (see CourtCard's onTap),
    // never go(), so a valid pop target (the list) stays on the stack.
    router.push('/courts/abc123');
    await tester.pumpAndSettle();
    expect(find.byType(CourtDetailPage), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(CourtsListPage), findsOneWidget);
  });

  testWidgets('the bottom navigation switches between Liste and Carte', (
    tester,
  ) async {
    await _pumpRouterApp(tester);

    expect(find.byType(CourtsListPage), findsOneWidget);
    expect(find.byType(CourtsMapPage), findsNothing);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();

    expect(find.byType(CourtsMapPage), findsOneWidget);

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(find.byType(CourtsListPage), findsOneWidget);
  });

  testWidgets(
    'a cold start at a court detail deep link shows CourtDetailPage, and '
    'the back gesture (with no push history) falls back to CourtsListPage',
    (tester) async {
      await _pumpRouterAppAt(tester, '/courts/osm:way-1');

      expect(find.byType(CourtDetailPage), findsOneWidget);
      final detailPage = tester.widget<CourtDetailPage>(
        find.byType(CourtDetailPage),
      );
      expect(detailPage.courtId, 'osm:way-1');

      // A cold deep link has no push history, so GoRouter.pop() would throw;
      // BackToHomeScope handles this by intercepting the system/back-gesture
      // pop attempt (simulated here via Navigator.maybePop) and going home.
      final context = tester.element(find.byType(CourtDetailPage));
      await Navigator.maybePop(context);
      await tester.pumpAndSettle();

      expect(find.byType(CourtsListPage), findsOneWidget);
    },
  );

  group('onboarding gate', () {
    testWidgets(
      'redirects to OnboardingPage when onboarding has not been completed',
      (tester) async {
        await _pumpRouterApp(tester, onboardingCompleted: false);

        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(find.byType(CourtsListPage), findsNothing);
      },
    );

    testWidgets(
      'redirects away from OnboardingPage once it has been completed',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await _onboardingCompletedPrefs(),
            ),
            nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
              yield _fixedCourts;
            }),
          ],
        );
        addTearDown(container.dispose);
        final router = container.read(goRouterProvider);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        router.go(Routes.onboarding);
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingPage), findsNothing);
        expect(find.byType(CourtsListPage), findsOneWidget);
      },
    );
  });
}
