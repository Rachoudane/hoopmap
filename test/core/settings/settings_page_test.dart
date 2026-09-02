import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:hoopmap/core/settings/app_info.dart';
import 'package:hoopmap/core/settings/pages/settings_page.dart';
import 'package:hoopmap/core/settings/settings_providers.dart';
import 'package:hoopmap/core/terms/pages/terms_of_use_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> initialPreferences = const {},
]) async {
  SharedPreferences.setMockInitialValues(initialPreferences);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpSettings(
  WidgetTester tester,
  ProviderContainer container,
) async {
  // The screen is a long list; a taller surface builds all of it and saves
  // every test from scrolling to what it asserts.
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: Routes.settings,
    routes: [
      GoRoute(
        path: Routes.settings,
        name: Routes.settingsName,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: Routes.terms,
        name: Routes.termsName,
        builder: (context, state) => const TermsOfUsePage(),
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
  group('themeModeProvider', () {
    test('follows the system until told otherwise', () async {
      final container = await _container();

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('remembers a choice across launches', () async {
      final container = await _container();

      await container.read(themeModeProvider.notifier).set(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      final relaunched = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(relaunched.dispose);
      expect(relaunched.read(themeModeProvider), ThemeMode.dark);
    });

    test('is stored by name, not by index', () async {
      final container = await _container();

      await container.read(themeModeProvider.notifier).set(ThemeMode.light);

      final preferences = await SharedPreferences.getInstance();
      // An index would silently mean something else if ThemeMode were ever
      // reordered upstream.
      expect(preferences.getString('theme_mode'), 'light');
    });

    test('an unrecognized stored value falls back to the system', () async {
      final container = await _container({'theme_mode': 'solarized'});

      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });

  group('searchRadiusProvider', () {
    test('defaults to the radius the app shipped with', () async {
      final container = await _container();

      expect(container.read(searchRadiusProvider), defaultSearchRadiusInMeters);
      expect(searchRadiusChoices, contains(defaultSearchRadiusInMeters));
    });

    test('remembers a choice across launches', () async {
      final container = await _container();

      await container.read(searchRadiusProvider.notifier).set(10000);

      final relaunched = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(relaunched.dispose);
      expect(relaunched.read(searchRadiusProvider), 10000);
    });

    test('a stored radius the picker could not show falls back', () async {
      final container = await _container({'search_radius_in_meters': 37.0});

      // An area no control can explain is worse than the one it can.
      expect(container.read(searchRadiusProvider), defaultSearchRadiusInMeters);
    });
  });

  group('SettingsPage', () {
    testWidgets('changing the theme applies and persists it', (tester) async {
      final container = await _container();
      await _pumpSettings(tester, container);

      await tester.tap(find.text(AppStrings.settingsThemeDark));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    testWidgets('changing the radius applies and persists it', (tester) async {
      final container = await _container();
      await _pumpSettings(tester, container);

      await tester.tap(find.text(AppStrings.settingsRadiusLabel(10000)));
      await tester.pumpAndSettle();

      expect(container.read(searchRadiusProvider), 10000);
    });

    testWidgets('offers every radius the search knows how to run', (
      tester,
    ) async {
      final container = await _container();
      await _pumpSettings(tester, container);

      for (final choice in searchRadiusChoices) {
        expect(
          find.text(AppStrings.settingsRadiusLabel(choice)),
          findsOneWidget,
          reason: 'the ${choice}m radius has no chip',
        );
      }
    });

    testWidgets('says which language the app speaks rather than staying '
        'silent about it', (tester) async {
      final container = await _container();
      await _pumpSettings(tester, container);

      expect(find.text(AppStrings.settingsLanguageTitle), findsOneWidget);
      expect(find.text(AppStrings.settingsLanguageSubtitle), findsOneWidget);
    });

    testWidgets('links to the Terms of Use and credits the data', (
      tester,
    ) async {
      final container = await _container();
      await _pumpSettings(tester, container);

      expect(find.text(AppStrings.settingsAttributionSubtitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.settingsTermsTitle));
      await tester.pumpAndSettle();

      expect(find.byType(TermsOfUsePage), findsOneWidget);
    });

    testWidgets('shows which build this is', (tester) async {
      final container = await _container();
      await _pumpSettings(tester, container);

      expect(
        find.text(AppStrings.settingsVersion(AppInfo.versionLabel)),
        findsOneWidget,
      );
    });
  });

  group('AppInfo', () {
    test('matches the version in pubspec.yaml', () {
      // The version is hand-kept (see app_info.dart); this is what stops it
      // from drifting.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*(\S+)\+(\S+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(match, isNotNull, reason: 'pubspec.yaml has no version line');
      expect(AppInfo.version, match!.group(1));
      expect(AppInfo.buildNumber, match.group(2));
    });
  });
}
