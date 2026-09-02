import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/onboarding/onboarding_providers.dart'
    show sharedPreferencesProvider;
import '../domain/city.dart';

const String _browseCityKey = 'browse_city';

/// The city the user chose to browse from, or null when the app is working
/// from their own position.
///
/// A chosen city wins over the device's location on purpose: it is the more
/// recent, more explicit statement of where the user wants to look, and
/// picking "Tokyo" only to be shown one's own street again would be absurd.
/// Coming back is one tap — "Use my location" in the picker, or the map's
/// recenter button — and both clear it.
///
/// Persisted, so a user with no location doesn't have to re-pick their city
/// on every launch. Stored by id and matched back against the bundled list,
/// so a stale value from a removed city resolves to null rather than to
/// coordinates nothing can explain.
class BrowseCityNotifier extends Notifier<City?> {
  @override
  City? build() {
    final storedId = ref
        .watch(sharedPreferencesProvider)
        .getString(_browseCityKey);
    if (storedId == null) return null;

    for (final city in browsableCities) {
      if (city.id == storedId) return city;
    }
    return null;
  }

  Future<void> choose(City city) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_browseCityKey, city.id);
    state = city;
  }

  /// Hands the search back to wherever the user actually is.
  Future<void> clear() async {
    await ref.read(sharedPreferencesProvider).remove(_browseCityKey);
    state = null;
  }
}

final NotifierProvider<BrowseCityNotifier, City?> browseCityProvider =
    NotifierProvider<BrowseCityNotifier, City?>(BrowseCityNotifier.new);
