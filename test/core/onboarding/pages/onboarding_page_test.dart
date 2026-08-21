import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

    expect(find.text('Trouvez un terrain, où que vous soyez'), findsOneWidget);
    expect(container.read(onboardingCompletedProvider), false);

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), true);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Suivant advances through all three slides then completes', (
    tester,
  ) async {
    final container = await _containerWithPrefs();
    addTearDown(container.dispose);
    await _pumpOnboarding(tester, container);

    expect(find.text('Trouvez un terrain, où que vous soyez'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Des données ouvertes et communautaires'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Votre position, uniquement pour ça'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), true);
    expect(find.text('Home'), findsOneWidget);
  });
}
