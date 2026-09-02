import 'dart:io';

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
import 'package:hoopmap/core/theme/app_colors.dart';
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
      Stream.value(const []);

  @override
  Stream<Court> watchCourt(String id) => Stream.value(_court);

  @override
  Future<String> addCourt(Court court) async => 'id';
}

final Court _court = Court(
  id: 'osm:node-1',
  name: 'Riverside Court',
  latitude: 48.8566,
  longitude: 2.3522,
  hoopCount: 2,
  isOutdoor: true,
  createdAt: DateTime(2026, 1, 1),
);

/// Every screen the app can show, built in the dark theme.
///
/// The point isn't that they render — that's asserted elsewhere — it's that
/// they render *dark*: a screen that paints its own background, or draws
/// text in a colour it chose itself, only shows up when the theme flips.
Future<void> _pumpDark(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1080, 2400);
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
      GoRoute(path: Routes.home, builder: (context, state) => page),
      GoRoute(
        path: Routes.terms,
        name: Routes.termsName,
        builder: (context, state) => const TermsOfUsePage(),
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
        courtDetailProvider.overrideWith((ref, id) => Stream.value(_court)),
        nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
          yield [CourtWithDistance(court: _court, distanceInMeters: 450)];
        }),
      ],
      child: MaterialApp.router(
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// The colour a [Scaffold] actually painted, read back off the widget tree.
Color _scaffoldBackgroundOf(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
  return scaffold.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
}

void main() {
  group('every screen honours the dark theme', () {
    final screens = <String, Widget>{
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

    for (final entry in screens.entries) {
      testWidgets('${entry.key} paints the dark background', (tester) async {
        await _pumpDark(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(
          _scaffoldBackgroundOf(tester),
          AppColors.asphalt,
          reason: '${entry.key} is not using the dark scaffold background',
        );
      });
    }

    testWidgets('body text is drawn in the dark theme\'s ink', (tester) async {
      await _pumpDark(tester, const SettingsPage());

      final context = tester.element(find.byType(SettingsPage));
      final theme = Theme.of(context);

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.onSurface, AppColors.textLight);
      expect(theme.textTheme.bodyMedium?.color, AppColors.textLight);
    });
  });

  group('no screen hard-codes a colour the theme should own', () {
    // A colour written into a widget is a colour that cannot flip with the
    // theme. The handful below are deliberate and explained; anything else
    // failing here is a screen that will look wrong in one of the two
    // themes, so justify it in this list or read it from the ColorScheme.
    const allowed = {
      // Over map tiles, which look the same in both themes: a scrim and its
      // label, and the shadows that lift a marker off them.
      'lib/features/courts/presentation/widgets/location_picker_map.dart',
      'lib/features/courts/presentation/widgets/map_attribution.dart',
      'lib/features/courts/presentation/widgets/court_marker.dart',
      'lib/features/courts/presentation/widgets/court_cluster_marker.dart',
      'lib/features/courts/presentation/widgets/user_location_marker.dart',
    };

    test('and the exceptions are only the documented ones', () {
      final offenders = <String>[];

      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final path = file.path.replaceAll(r'\', '/');
        if (path.startsWith('lib/core/theme/')) continue;
        if (path.endsWith('firebase_options.dart')) continue;
        if (allowed.contains(path)) continue;

        for (final line in file.readAsLinesSync()) {
          final usesRawColor =
              RegExp(r'\bColor\(0x').hasMatch(line) ||
              RegExp(r'\bColors\.(?!transparent\b)\w+').hasMatch(line);
          if (usesRawColor) offenders.add('$path: ${line.trim()}');
        }
      }

      expect(offenders, isEmpty);
    });
  });
}
