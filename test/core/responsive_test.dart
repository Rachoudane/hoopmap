import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/location/location_opt_in.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/core/location/pages/location_rationale_page.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/core/onboarding/pages/onboarding_page.dart';
import 'package:hoopmap/core/presentation/pages/not_found_page.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:hoopmap/core/settings/pages/settings_page.dart';
import 'package:hoopmap/core/terms/pages/terms_of_use_page.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hoopmap/core/presentation/widgets/readable_width.dart';
import 'package:hoopmap/core/theme/app_theme.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:hoopmap/features/courts/presentation/browse_city_provider.dart';
import 'package:hoopmap/features/courts/presentation/court_detail_provider.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/add_court_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_list_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_map_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/pick_city_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocationService extends LocationService {
  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<UserPosition> readPosition() async =>
      const UserPosition(latitude: 48.8566, longitude: 2.3522);

  @override
  Future<UserPosition?> lastKnownPosition() async => null;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _FakeCourtRepository implements CourtRepository {
  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) =>
      Stream.value([_court]);

  @override
  Stream<Court> watchCourt(String id) => Stream.value(_court);

  @override
  Future<String> addCourt(Court court) async => 'id';
}

final Court _court = Court(
  id: 'osm:node-1',
  // Long on purpose: a short name proves nothing about a narrow screen.
  name: 'Playground of the Cité Internationale Universitaire de Paris',
  latitude: 48.8566,
  longitude: 2.3522,
  hoopCount: 2,
  isOutdoor: true,
  createdAt: DateTime(2026, 1, 1),
);

/// The shapes a phone or tablet actually hands the app, in logical pixels.
///
/// The small phone is the one that matters most: at 320x568 with the
/// system's largest text, anything laid out for a comfortable screen breaks.
const Map<String, Size> _screenSizes = {
  'a small phone': Size(320, 568),
  'a phone in landscape': Size(720, 360),
  'a tablet': Size(834, 1112),
  'a tablet in landscape': Size(1112, 834),
};

Future<void> _pumpAt(WidgetTester tester, Widget page, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'onboarding_completed': true,
    'terms_of_use_accepted': true,
  });
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
        locationServiceProvider.overrideWithValue(_FakeLocationService()),
        courtRepositoryProvider.overrideWithValue(_FakeCourtRepository()),
        courtDetailProvider.overrideWith((ref, id) => Stream.value(_court)),
        nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
          yield [
            for (var i = 0; i < 6; i++)
              CourtWithDistance(court: _court, distanceInMeters: 450.0 * i),
          ];
        }),
      ],
      child: MaterialApp.router(
        theme: lightTheme,
        darkTheme: darkTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Map<String, Widget> _screens() => {
  'onboarding': const OnboardingPage(),
  'courts list': const CourtsListPage(),
  'map': const CourtsMapPage(),
  'court detail': const CourtDetailPage(courtId: 'osm:node-1'),
  'add court': const AddCourtPage(),
  'pick a city': const PickCityPage(),
  'settings': const SettingsPage(),
  'terms of use': const TermsOfUsePage(),
  'location rationale': const LocationRationalePage(),
  'not found': const NotFoundPage(),
};

void main() {
  // Overflow is reported as an exception in tests, so "nothing overflowed"
  // is something a test can actually assert — unlike "it looked fine on my
  // phone", which is how the layouts got this far unchecked.
  for (final size in _screenSizes.entries) {
    group('on ${size.key}', () {
      for (final screen in _screens().entries) {
        testWidgets('${screen.key} lays out without overflowing', (
          tester,
        ) async {
          await _pumpAt(tester, screen.value, size.value);

          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.key} overflows on ${size.key}',
          );
        });
      }
    });
  }

  group('with the system text at its largest', () {
    // The accessibility setting that breaks more layouts than any screen
    // size: every label grows, the screen does not.
    testWidgets('the screens that are mostly text still fit a small phone', (
      tester,
    ) async {
      for (final screen in _screens().entries) {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({
          'onboarding_completed': true,
          'terms_of_use_accepted': true,
        });
        final preferences = await SharedPreferences.getInstance();
        final router = GoRouter(
          initialLocation: Routes.home,
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => screen.value,
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              locationOptInProvider.overrideWithBuild((ref, notifier) => true),
              browseCityProvider.overrideWithBuild((ref, notifier) => null),
              locationServiceProvider.overrideWithValue(_FakeLocationService()),
              courtRepositoryProvider.overrideWithValue(_FakeCourtRepository()),
              courtDetailProvider.overrideWith(
                (ref, id) => Stream.value(_court),
              ),
              nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
                yield [CourtWithDistance(court: _court, distanceInMeters: 450)];
              }),
            ],
            child: MaterialApp.router(
              theme: lightTheme,
              routerConfig: router,
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.5,
                maxScaleFactor: 1.5,
                child: child!,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.key} overflows at 1.5x text on a small phone',
        );
      }
    });
  });

  group('on a tablet, content stops before the bezels', () {
    // 1112 logical pixels of paragraph is a line the eye loses halfway, and
    // a button that reaches from one edge of a tablet to the other.
    const tablet = Size(1112, 834);

    testWidgets('the courts list is capped, not stretched', (tester) async {
      await _pumpAt(tester, const CourtsListPage(), tablet);

      final listWidth = tester.getSize(find.byType(ListView).first).width;
      expect(listWidth, lessThanOrEqualTo(ReadableWidth.defaultMaxWidth));
      expect(listWidth, greaterThan(400));
    });

    testWidgets('so are the settings and the forms', (tester) async {
      await _pumpAt(tester, const SettingsPage(), tablet);
      expect(
        tester.getSize(find.byType(ListView).first).width,
        lessThanOrEqualTo(ReadableWidth.defaultMaxWidth),
      );

      await _pumpAt(tester, const AddCourtPage(), tablet);
      expect(
        tester.getSize(find.byType(ListView).first).width,
        lessThanOrEqualTo(ReadableWidth.defaultMaxWidth),
      );
    });

    testWidgets('the map still gets every pixel, being a map', (tester) async {
      await _pumpAt(tester, const CourtsMapPage(), tablet);

      expect(tester.getSize(find.byType(FlutterMap)).width, tablet.width);
    });
  });
}
