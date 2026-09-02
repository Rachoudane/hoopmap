import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Override, the type of a ProviderScope's overrides, lives outside the
// package's default export.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/location/location_opt_in.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/core/presentation/widgets/app_message_view.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:hoopmap/features/courts/data/overpass_court_repository.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/presentation/browse_city_provider.dart';
import 'package:hoopmap/features/courts/presentation/court_detail_provider.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_list_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/pick_city_page.dart';
import 'package:hoopmap/features/courts/presentation/widgets/court_detail_skeleton.dart';
import 'package:hoopmap/features/courts/presentation/widgets/court_list_skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'onboarding_completed': true});
  final preferences = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [GoRoute(path: Routes.home, builder: (context, state) => page)],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        locationOptInProvider.overrideWithBuild((ref, notifier) => true),
        browseCityProvider.overrideWithBuild((ref, notifier) => null),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

void main() {
  group('the courts list', () {
    testWidgets('waits with the shape of the list, not a spinner', (
      tester,
    ) async {
      await _pump(
        tester,
        const CourtsListPage(),
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            // Never yields: still searching.
          }),
        ],
      );

      expect(find.byType(CourtListSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('says what an empty result means, and what to do', (
      tester,
    ) async {
      await _pump(
        tester,
        const CourtsListPage(),
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            yield const <CourtWithDistance>[];
          }),
        ],
      );

      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.text(AppStrings.addFirstCourt), findsOneWidget);
    });

    testWidgets('explains a failure and offers a way on', (tester) async {
      await _pump(
        tester,
        const CourtsListPage(),
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            throw OverpassException('boom');
          }),
        ],
      );

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);
    });
  });

  group('a court detail page', () {
    testWidgets('waits with the shape of the page', (tester) async {
      await _pump(
        tester,
        const CourtDetailPage(courtId: 'osm:node-1'),
        overrides: [
          courtDetailProvider.overrideWith(
            (ref, id) => const Stream<Court>.empty(),
          ),
        ],
      );

      // Opened cold from a deep link, this is the first thing a new user
      // ever sees of the app.
      expect(find.byType(CourtDetailSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a court that no longer exists is an empty state, not an '
        'error', (tester) async {
      await _pump(
        tester,
        const CourtDetailPage(courtId: 'osm:node-1'),
        overrides: [
          courtDetailProvider.overrideWith(
            (ref, id) => Stream.error(CourtNotFoundException(id)),
          ),
        ],
      );

      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.text(AppStrings.backToList), findsOneWidget);
    });

    testWidgets('any other failure is explained and retryable', (tester) async {
      await _pump(
        tester,
        const CourtDetailPage(courtId: 'osm:node-1'),
        overrides: [
          courtDetailProvider.overrideWith(
            (ref, id) => Stream.error(OverpassException('boom')),
          ),
        ],
      );

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);
    });
  });

  group('the city picker', () {
    testWidgets('a search that matches nothing gets the same empty state as '
        'everywhere else', (tester) async {
      await _pump(tester, const PickCityPage());

      await tester.enterText(find.byType(TextField), 'Atlantis');
      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.text(AppStrings.pickCityNoMatchTitle), findsOneWidget);
    });
  });

  group('across the app', () {
    test('no screen answers a wait with a bare centred spinner', () {
      // A spinner in the middle of an empty screen says "wait" and nothing
      // else. Every wait in this app is either a skeleton of what is
      // coming, or a small indicator inside the control that is busy.
      final offenders = <String>[];

      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');
        if (source.contains('Center( child: CircularProgressIndicator()')) {
          offenders.add(file.path.replaceAll(r'\', '/'));
        }
      }

      expect(offenders, isEmpty);
    });
  });
}
