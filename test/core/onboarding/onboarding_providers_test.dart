import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/onboarding/onboarding_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SharedPreferences.setMockInitialValues swaps in an in-memory
// implementation, so getInstance() never touches a real platform channel.
Future<ProviderContainer> _containerWith(
  Map<String, Object> initialValues,
) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  return container;
}

void main() {
  group('onboardingCompletedProvider', () {
    test('is false when no value has been persisted yet', () async {
      final container = await _containerWith({});
      addTearDown(container.dispose);

      expect(container.read(onboardingCompletedProvider), false);
    });

    test('reflects a previously persisted true value', () async {
      final container = await _containerWith({'onboarding_completed': true});
      addTearDown(container.dispose);

      expect(container.read(onboardingCompletedProvider), true);
    });

    test('complete() flips the state to true and persists it', () async {
      final container = await _containerWith({});
      addTearDown(container.dispose);

      expect(container.read(onboardingCompletedProvider), false);

      await container.read(onboardingCompletedProvider.notifier).complete();

      expect(container.read(onboardingCompletedProvider), true);

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getBool('onboarding_completed'), true);
    });

    test('a fresh provider read after completion stays true', () async {
      final container = await _containerWith({});
      addTearDown(container.dispose);
      await container.read(onboardingCompletedProvider.notifier).complete();

      final prefs = container.read(sharedPreferencesProvider);
      final otherContainer = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(otherContainer.dispose);

      expect(otherContainer.read(onboardingCompletedProvider), true);
    });
  });
}
