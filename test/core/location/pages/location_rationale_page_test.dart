import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/location/location_opt_in.dart';
import 'package:hoopmap/core/location/location_opt_in_flow.dart';
import 'package:hoopmap/core/location/pages/location_rationale_page.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A screen that asks for the location the way the app's screens do, and
/// records what came back.
class _Asker extends ConsumerWidget {
  const _Asker({required this.results});

  final List<bool> results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async =>
              results.add(await requestLocationOptIn(context, ref)),
          child: const Text('ask'),
        ),
      ),
    );
  }
}

Future<ProviderContainer> _pumpAsker(
  WidgetTester tester,
  List<bool> results, {
  bool alreadyOptedIn = false,
}) async {
  SharedPreferences.setMockInitialValues({
    if (alreadyOptedIn) 'location_opt_in': true,
  });
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => _Asker(results: results),
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
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('says what the location is for, and what happens next', (
    tester,
  ) async {
    final results = <bool>[];
    await _pumpAsker(tester, results);

    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.locationRationaleTitle), findsOneWidget);
    // The three things Android's own dialog cannot say.
    expect(
      find.text(AppStrings.locationRationaleReasonDistance),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.locationRationaleReasonWhileOpen),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.locationRationaleReasonPrivate),
      findsOneWidget,
    );
    // And a warning that the system is about to ask, so its dialog arrives
    // as the consequence of a button rather than as an interruption.
    expect(find.text(AppStrings.locationRationaleNextStep), findsOneWidget);
  });

  testWidgets('allowing opts in and reports it to the caller', (tester) async {
    final results = <bool>[];
    final container = await _pumpAsker(tester, results);

    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.locationRationaleAllow));
    await tester.pumpAndSettle();

    expect(container.read(locationOptInProvider), isTrue);
    expect(results, [true]);
    expect(find.text(AppStrings.locationRationaleTitle), findsNothing);
  });

  testWidgets('"Not now" grants nothing and can be asked again', (
    tester,
  ) async {
    final results = <bool>[];
    final container = await _pumpAsker(tester, results);

    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.locationRationaleNotNow));
    await tester.pumpAndSettle();

    expect(container.read(locationOptInProvider), isFalse);
    expect(results, [false]);

    // Nothing was spent: unlike the system dialog, this can be offered again.
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.locationRationaleTitle), findsOneWidget);
  });

  testWidgets('backing out of the explanation grants nothing either', (
    tester,
  ) async {
    final results = <bool>[];
    final container = await _pumpAsker(tester, results);

    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(container.read(locationOptInProvider), isFalse);
    expect(results, [false]);
  });

  testWidgets('a user who already opted in is not explained to again', (
    tester,
  ) async {
    final results = <bool>[];
    await _pumpAsker(tester, results, alreadyOptedIn: true);

    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();

    // The explanation is for the first time, not for every use.
    expect(find.text(AppStrings.locationRationaleTitle), findsNothing);
    expect(results, [true]);
  });
}
