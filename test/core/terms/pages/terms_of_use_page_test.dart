import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/core/terms/pages/terms_of_use_page.dart';
import 'package:hoopmap/core/terms/terms_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _containerWithPrefs() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Home'))),
    ),
    GoRoute(path: '/view', builder: (context, state) => const TermsOfUsePage()),
    GoRoute(
      path: '/gate',
      builder: (context, state) =>
          const TermsOfUsePage(requireAcceptance: true),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  GoRouter router,
) async {
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
  testWidgets(
    'view mode shows the Terms of Use content without Accept/Decline',
    (tester) async {
      final container = await _containerWithPrefs();
      addTearDown(container.dispose);
      final router = _router();
      await _pump(tester, container, router);

      router.push('/view');
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.termsOfUseTitle), findsOneWidget);
      expect(find.text('1. What Hoopmap is'), findsOneWidget);
      expect(find.text(AppStrings.termsAccept), findsNothing);
      expect(find.text(AppStrings.termsDecline), findsNothing);
    },
  );

  testWidgets('gate mode: Accept persists acceptance and returns', (
    tester,
  ) async {
    final container = await _containerWithPrefs();
    addTearDown(container.dispose);
    final router = _router();
    await _pump(tester, container, router);

    router.push('/gate');
    await tester.pumpAndSettle();
    expect(container.read(termsAcceptedProvider), false);

    await tester.tap(find.text(AppStrings.termsAccept));
    await tester.pumpAndSettle();

    expect(container.read(termsAcceptedProvider), true);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('gate mode: Decline returns without persisting acceptance', (
    tester,
  ) async {
    final container = await _containerWithPrefs();
    addTearDown(container.dispose);
    final router = _router();
    await _pump(tester, container, router);

    router.push('/gate');
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.termsDecline));
    await tester.pumpAndSettle();

    expect(container.read(termsAcceptedProvider), false);
    expect(find.text('Home'), findsOneWidget);
  });
}
