import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

final List<CourtWithDistance> _fixedCourts = [
  CourtWithDistance(
    court: Court(
      id: 'court-a',
      name: 'Terrain A',
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
  name: 'Terrain $id',
  latitude: 0,
  longitude: 0,
  hoopCount: 1,
  isOutdoor: true,
  createdAt: DateTime(2026, 1, 1),
);

Future<GoRouter> _pumpRouterApp(WidgetTester tester) async {
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
  final GoRouter router = container.read(goRouterProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  return router;
}

// app_router.dart hardcodes initialLocation to Routes.home, so a cold start
// at a deep-linked location is exercised here by building an equivalent
// router directly with a custom initialLocation.
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
        routes: [
          GoRoute(
            path: Routes.courtDetail,
            name: Routes.courtDetailName,
            builder: (context, state) {
              final courtId = state.pathParameters[Routes.courtIdParam]!;
              return CourtDetailPage(courtId: courtId);
            },
          ),
          GoRoute(
            path: Routes.map,
            name: Routes.mapName,
            builder: (context, state) => const CourtsMapPage(),
          ),
        ],
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

    router.go('/courts/abc123');
    await tester.pumpAndSettle();
    expect(find.byType(CourtDetailPage), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(CourtsListPage), findsOneWidget);
  });

  testWidgets(
    'a cold start at a court detail deep link shows CourtDetailPage, and '
    'popping returns to CourtsListPage',
    (tester) async {
      final router = await _pumpRouterAppAt(tester, '/courts/osm:way-1');

      expect(find.byType(CourtDetailPage), findsOneWidget);
      final detailPage = tester.widget<CourtDetailPage>(
        find.byType(CourtDetailPage),
      );
      expect(detailPage.courtId, 'osm:way-1');

      router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(CourtsListPage), findsOneWidget);
    },
  );
}
