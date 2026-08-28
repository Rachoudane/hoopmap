import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/app.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';
import 'package:hoopmap/features/courts/presentation/court_detail_provider.dart';
import 'package:hoopmap/features/courts/presentation/nearby_courts_notifier.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_list_page.dart';
import 'package:hoopmap/features/courts/presentation/widgets/court_list_skeleton.dart';
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
}

Court _court(String id, String name) => Court(
  id: id,
  name: name,
  latitude: 0,
  longitude: 0,
  hoopCount: 1,
  isOutdoor: true,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  testWidgets(
    'displays courts sorted by distance with formatted distances, and '
    'navigates to detail on tap',
    (tester) async {
      final courts = [
        CourtWithDistance(
          court: _court('court-a', 'Court A'),
          distanceInMeters: 450,
        ),
        CourtWithDistance(
          court: _court('court-b', 'Court B'),
          distanceInMeters: 1200,
        ),
        CourtWithDistance(
          court: _court('court-c', 'Court C'),
          distanceInMeters: 2400,
        ),
      ];

      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final sharedPreferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
              yield courts;
            }),
            // CourtDetailPage reads courtDetailProvider, which otherwise
            // hits the real courtRepositoryProvider chain (http + Firestore)
            // once the test taps through to it.
            courtDetailProvider(
              'court-a',
            ).overrideWith((ref) => Stream.value(_court('court-a', 'Court A'))),
          ],
          child: const HoopmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Court A'), findsOneWidget);
      expect(find.text('Court B'), findsOneWidget);
      expect(find.text('Court C'), findsOneWidget);
      expect(find.text('450 m'), findsOneWidget);
      expect(find.text('1.2 km'), findsOneWidget);

      final positionA = tester.getCenter(find.text('Court A')).dy;
      final positionB = tester.getCenter(find.text('Court B')).dy;
      final positionC = tester.getCenter(find.text('Court C')).dy;
      expect(positionA, lessThan(positionB));
      expect(positionB, lessThan(positionC));

      await tester.tap(find.text('Court A'));
      await tester.pumpAndSettle();

      final detailPage = tester.widget<CourtDetailPage>(
        find.byType(CourtDetailPage),
      );
      expect(detailPage.courtId, 'court-a');
    },
  );

  testWidgets('shows a skeleton, not a bare spinner, while loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            // Never yields: the page should still be in its loading state.
          }),
        ],
        child: const MaterialApp(home: CourtsListPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(CourtListSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an illustrated empty state with a working action', (
    tester,
  ) async {
    var invalidated = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            ref.onDispose(() => invalidated = true);
            yield const [];
          }),
        ],
        child: const MaterialApp(home: CourtsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('No courts nearby'), findsOneWidget);

    await tester.tap(find.text('Refresh'));
    await tester.pump();

    expect(invalidated, true);
  });

  testWidgets('shows a human-readable error with a working retry button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
            throw Exception('boom');
          }),
        ],
        child: const MaterialApp(home: CourtsListPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'tapping "Add a court" before accepting the Terms of Use shows the '
    'acceptance gate, and accepting continues to the add-court form',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final sharedPreferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
              yield const [];
            }),
            locationServiceProvider.overrideWithValue(_FakeLocationService()),
          ],
          child: const HoopmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.termsGateIntro), findsOneWidget);
      expect(find.text(AppStrings.addCourtTitle), findsNothing);

      await tester.tap(find.text(AppStrings.termsAccept));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.termsGateIntro), findsNothing);
      expect(find.text(AppStrings.addCourtTitle), findsOneWidget);
    },
  );

  testWidgets(
    'tapping "Add a court" after the Terms of Use were already accepted '
    'goes straight to the form',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'terms_of_use_accepted': true,
      });
      final sharedPreferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            nearbyCourtsProvider.overrideWithBuild((ref, notifier) async* {
              yield const [];
            }),
            locationServiceProvider.overrideWithValue(_FakeLocationService()),
          ],
          child: const HoopmapApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.termsGateIntro), findsNothing);
      expect(find.text(AppStrings.addCourtTitle), findsOneWidget);
    },
  );
}
