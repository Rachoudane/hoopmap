import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/location/location_opt_in.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/core/onboarding/pages/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _containerWithPrefs() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

Future<void> _pumpOnboarding(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
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
}

void main() {
  testWidgets('shows the first slide and a working Skip button', (
    tester,
  ) async {
    final container = await _containerWithPrefs();
    addTearDown(container.dispose);
    await _pumpOnboarding(tester, container);

    expect(find.text(AppStrings.onboardingSlide1Title), findsOneWidget);
    expect(container.read(onboardingCompletedProvider), false);

    await tester.tap(find.text(AppStrings.onboardingSkip));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), true);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Next advances through all three slides then completes', (
    tester,
  ) async {
    final container = await _containerWithPrefs();
    addTearDown(container.dispose);
    await _pumpOnboarding(tester, container);

    expect(find.text(AppStrings.onboardingSlide1Title), findsOneWidget);

    await tester.tap(find.text(AppStrings.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.onboardingSlide2Title), findsOneWidget);

    await tester.tap(find.text(AppStrings.onboardingNext));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.onboardingSlide3Title), findsOneWidget);
    expect(find.text(AppStrings.onboardingGetStarted), findsOneWidget);

    await tester.tap(find.text(AppStrings.onboardingGetStarted));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), true);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('the last slide asks for nothing until its button is pressed', (
    tester,
  ) async {
    final container = await _containerWithPrefs();
    addTearDown(container.dispose);
    await _pumpOnboarding(tester, container);

    await tester.tap(find.text(AppStrings.onboardingNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.onboardingNext));
    await tester.pumpAndSettle();

    // Reaching the end of the carousel is not a request for anything.
    expect(container.read(locationOptInProvider), false);

    await tester.tap(find.text(AppStrings.onboardingGetStarted));
    await tester.pumpAndSettle();

    // The permission dialog belongs to a button the user pressed, and this
    // is that button.
    expect(container.read(locationOptInProvider), true);
  });

  testWidgets('"Browse without location" enters the app having asked for '
      'nothing', (tester) async {
    final container = await _containerWithPrefs();
    addTearDown(container.dispose);
    await _pumpOnboarding(tester, container);

    await tester.tap(find.text(AppStrings.onboardingNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.onboardingNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.onboardingBrowseInstead));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), true);
    expect(container.read(locationOptInProvider), false);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Skip leaves the location alone as well', (tester) async {
    final container = await _containerWithPrefs();
    addTearDown(container.dispose);
    await _pumpOnboarding(tester, container);

    await tester.tap(find.text(AppStrings.onboardingSkip));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), true);
    expect(container.read(locationOptInProvider), false);
  });

  testWidgets('the way out of the carousel is offered only at the end', (
    tester,
  ) async {
    final container = await _containerWithPrefs();
    addTearDown(container.dispose);
    await _pumpOnboarding(tester, container);

    // On the value slides, Skip is the only exit; the location choice is
    // presented once the user knows what they would be granting it for.
    expect(find.text(AppStrings.onboardingBrowseInstead), findsNothing);

    await tester.tap(find.text(AppStrings.onboardingNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.onboardingNext));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.onboardingBrowseInstead), findsOneWidget);
  });
}
