import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _onboardingCompletedKey = 'onboarding_completed';

// Must be overridden with a resolved instance before the app (or a test)
// reads onboardingCompletedProvider: main.dart awaits
// SharedPreferences.getInstance() before building the ProviderContainer so
// this stays a synchronous Provider rather than a FutureProvider, which
// keeps the router's redirect logic (see app_router.dart) synchronous too.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (ref) => throw UnimplementedError(
        'sharedPreferencesProvider must be overridden with a resolved '
        'SharedPreferences instance.',
      ),
    );

/// Whether the first-launch onboarding has already been shown, persisted
/// across app launches. Read synchronously by the router's redirect so
/// onboarding gates every route until [complete] is called.
class OnboardingCompletedNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .watch(sharedPreferencesProvider)
            .getBool(_onboardingCompletedKey) ??
        false;
  }

  Future<void> complete() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_onboardingCompletedKey, true);
    state = true;
  }
}

final NotifierProvider<OnboardingCompletedNotifier, bool>
onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
      OnboardingCompletedNotifier.new,
    );
