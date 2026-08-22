import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:hoopmap/core/terms/terms_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _containerWithPrefs(
  Map<String, Object> values,
) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  test('defaults to false when nothing was persisted', () async {
    final container = await _containerWithPrefs({});
    addTearDown(container.dispose);

    expect(container.read(termsAcceptedProvider), false);
  });

  test('reads a previously persisted acceptance', () async {
    final container = await _containerWithPrefs({
      'terms_of_use_accepted': true,
    });
    addTearDown(container.dispose);

    expect(container.read(termsAcceptedProvider), true);
  });

  test('accept() persists true and updates the provider state', () async {
    final container = await _containerWithPrefs({});
    addTearDown(container.dispose);
    expect(container.read(termsAcceptedProvider), false);

    await container.read(termsAcceptedProvider.notifier).accept();

    expect(container.read(termsAcceptedProvider), true);
    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getBool('terms_of_use_accepted'), true);
  });
}
