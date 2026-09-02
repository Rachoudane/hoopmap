import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/auth/auth_providers.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/core/location/location_opt_in.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:hoopmap/features/courts/presentation/pages/add_court_page.dart';
import 'package:hoopmap/features/courts/presentation/widgets/location_picker_map.dart';
import 'package:latlong2/latlong.dart';

class _FakeLocationService extends LocationService {
  int readPositionCallCount = 0;

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<UserPosition> readPosition() async {
    readPositionCallCount++;
    return const UserPosition(latitude: 48.8566, longitude: 2.3522);
  }

  @override
  Future<UserPosition?> lastKnownPosition() async => null;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

/// Never resolves on its own: lets a test observe the state before the
/// initial position is known, then [complete] it to move on.
class _DelayedLocationService extends LocationService {
  final _completer = Completer<UserPosition>();

  void complete(UserPosition position) => _completer.complete(position);

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<UserPosition> readPosition() => _completer.future;

  @override
  Future<UserPosition?> lastKnownPosition() async => null;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _FakeCourtRepository implements CourtRepository {
  int addCourtCallCount = 0;
  Court? lastAddedCourt;

  @override
  Future<String> addCourt(Court court) async {
    addCourtCallCount++;
    lastAddedCourt = court;
    return 'new-court-id';
  }

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) =>
      Stream.error(UnimplementedError());

  @override
  Stream<Court> watchCourt(String id) => Stream.error(UnimplementedError());
}

// AddCourtPage calls context.pop() and shows a SnackBar on success, so it is
// pumped as a real sub-route of home rather than in isolation.
// Reached in the real app only via a push from the FAB on CourtsListPage
// (see courts_list_page.dart), never as the initial location: pushing here
// too keeps a valid pop target on the stack, matching _submit()'s
// unconditional context.pop() on success.
//
// Uses explicit pump() calls rather than pumpAndSettle(): the page embeds a
// live FlutterMap, whose tile layer keeps retrying network image loads in
// the test sandbox and never fully quiesces (same reason
// courts_map_page_test.dart avoids pumpAndSettle()).
Future<_FakeCourtRepository> _pumpAddCourtPage(
  WidgetTester tester, {
  LocationService? locationService,
  bool optedIntoLocation = true,
}) async {
  // The map picker pushes the rest of the form (position summary, "Saisir
  // coordinates", the submit button) below the default test surface's
  // viewport + cache extent, leaving them unbuilt. A taller surface avoids
  // scrolling gymnastics for every interaction below the map.
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repository = _FakeCourtRepository();
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
      ),
      GoRoute(
        path: Routes.addCourt,
        builder: (context, state) => const AddCourtPage(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // A user who has already asked for their location: the form
        // prefilling from GPS is what these tests are about, and the opt-in
        // that unlocks it has its own tests.
        locationOptInProvider.overrideWithBuild(
          (ref, notifier) => optedIntoLocation,
        ),
        courtRepositoryProvider.overrideWithValue(repository),
        anonymousSessionProvider.overrideWith((ref) async => 'test-uid'),
        locationServiceProvider.overrideWithValue(
          locationService ?? _FakeLocationService(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push(Routes.addCourt);
  // One pump for the push/build, a couple more to let the initial GPS
  // future resolve and the map picker replace its loading placeholder.
  await tester.pump();
  await tester.pump();
  await tester.pump();

  return repository;
}

void main() {
  testWidgets(
    'a name that is too short shows a validation error and does not call '
    'the repository',
    (tester) async {
      final repository = await _pumpAddCourtPage(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'ab');
      await tester.enterText(find.byType(TextFormField).at(1), '4');

      await tester.tap(find.text('Add court'));
      await tester.pump();

      expect(
        find.text('Name must be between 3 and 60 characters'),
        findsOneWidget,
      );
      expect(repository.addCourtCallCount, 0);
    },
  );

  testWidgets('a valid form submits using the GPS-prefilled position, without '
      'touching the map or the coordinate fields', (tester) async {
    final repository = await _pumpAddCourtPage(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Valid Court');
    await tester.enterText(find.byType(TextFormField).at(1), '4');

    await tester.tap(find.text('Add court'));
    await tester.pump();

    expect(repository.addCourtCallCount, 1);
    expect(repository.lastAddedCourt?.latitude, closeTo(48.8566, 0.0001));
    expect(repository.lastAddedCourt?.longitude, closeTo(2.3522, 0.0001));
  });

  testWidgets(
    'moving the map picker updates the displayed and submitted position',
    (tester) async {
      final repository = await _pumpAddCourtPage(tester);

      final mapWidget = tester.widget<LocationPickerMap>(
        find.byType(LocationPickerMap),
      );
      mapWidget.onCenterChanged(const LatLng(45.7640, 4.8357));
      await tester.pump();

      expect(find.textContaining('45.764000'), findsOneWidget);
      expect(find.textContaining('4.835700'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Moved Court');
      await tester.enterText(find.byType(TextFormField).at(1), '3');
      await tester.tap(find.text('Add court'));
      await tester.pump();

      expect(repository.addCourtCallCount, 1);
      expect(repository.lastAddedCourt?.latitude, closeTo(45.764, 0.0001));
      expect(repository.lastAddedCourt?.longitude, closeTo(4.8357, 0.0001));
    },
  );

  testWidgets('"My current location" re-fetches and applies the GPS position', (
    tester,
  ) async {
    final repository = await _pumpAddCourtPage(tester);

    final mapWidget = tester.widget<LocationPickerMap>(
      find.byType(LocationPickerMap),
    );
    mapWidget.onCenterChanged(const LatLng(0, 0));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('0.000000'), findsWidgets);

    // Invokes the button's callback directly rather than tap(): the map
    // picker's own layout makes precise on-screen hit-test coordinates
    // for widgets below it unreliable at the taller test surface size
    // this file uses, which isn't what this test is about.
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'My current location'),
    );
    button.onPressed!();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('48.856600'), findsOneWidget);
    expect(find.textContaining('2.352200'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'GPS Court');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.tap(find.text('Add court'));
    await tester.pump();

    expect(repository.addCourtCallCount, 1);
    expect(repository.lastAddedCourt?.latitude, closeTo(48.8566, 0.0001));
  });

  testWidgets(
    'manual coordinate entry is collapsed by default, and still validates '
    'once expanded',
    (tester) async {
      final repository = await _pumpAddCourtPage(tester);

      expect(find.text('Enter coordinates'), findsOneWidget);
      final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
      expect(tile.initiallyExpanded, false);

      await tester.tap(find.text('Enter coordinates'));
      await tester.pump();

      expect(find.text('Latitude'), findsOneWidget);
      expect(find.text('Longitude'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Manual Court');
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      // Latitude out of range: submission must be blocked.
      await tester.enterText(find.byType(TextFormField).at(2), '120');
      await tester.enterText(find.byType(TextFormField).at(3), '2.3522');

      await tester.tap(find.text('Add court'));
      await tester.pump();

      expect(find.text('Between -90 and 90'), findsOneWidget);
      expect(repository.addCourtCallCount, 0);
    },
  );

  testWidgets(
    'the submit button stays disabled until an initial position is known',
    (tester) async {
      final delayedLocationService = _DelayedLocationService();
      await _pumpAddCourtPage(tester, locationService: delayedLocationService);

      final buttonBefore = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add court'),
      );
      expect(buttonBefore.onPressed, isNull);

      delayedLocationService.complete(
        const UserPosition(latitude: 48.8566, longitude: 2.3522),
      );
      await tester.pump();
      await tester.pump();

      final buttonAfter = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add court'),
      );
      expect(buttonAfter.onPressed, isNotNull);
    },
  );

  testWidgets('opening the form asks the device for nothing when the user '
      'never opted in', (tester) async {
    final locationService = _FakeLocationService();
    await _pumpAddCourtPage(
      tester,
      locationService: locationService,
      optedIntoLocation: false,
    );

    // Reaching a form is not a request for a location, and the picker has a
    // perfectly good fallback centre to start from.
    expect(locationService.readPositionCallCount, 0);
    expect(find.byType(LocationPickerMap), findsOneWidget);
  });
}
