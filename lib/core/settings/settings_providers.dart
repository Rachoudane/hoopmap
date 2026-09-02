import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding/onboarding_providers.dart' show sharedPreferencesProvider;

const String _themeModeKey = 'theme_mode';
const String _searchRadiusKey = 'search_radius_in_meters';

/// How the app picks between its light and dark themes.
///
/// Persisted as the enum's name rather than its index, so reordering
/// [ThemeMode] upstream can't silently turn someone's "dark" into "light".
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getString(_themeModeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      // Following the system is the default, and the answer for anything
      // unrecognized: a stored value from a future version must not leave
      // the app themeless.
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_themeModeKey, mode.name);
    state = mode;
  }
}

final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// The radii offered for the "courts near me" search, in meters.
///
/// Discrete choices rather than a slider: the value goes straight into an
/// Overpass bounding box, and a service run by volunteers is better served
/// by five predictable areas than by every value between them.
const List<double> searchRadiusChoices = [1000, 2000, 5000, 10000, 20000];

/// The default, and the radius the app shipped with before this was a choice.
const double defaultSearchRadiusInMeters = 5000;

/// How far around the user (or the city they picked) the app looks.
///
/// Stored as meters. A value that isn't one of [searchRadiusChoices] — from
/// an older build, or a hand-edited preference — falls back to the default
/// rather than being honoured: the picker could not show it, and an area the
/// UI can't explain is worse than the one it can.
class SearchRadiusNotifier extends Notifier<double> {
  @override
  double build() {
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getDouble(_searchRadiusKey);
    if (stored == null || !searchRadiusChoices.contains(stored)) {
      return defaultSearchRadiusInMeters;
    }
    return stored;
  }

  Future<void> set(double radiusInMeters) async {
    await ref
        .read(sharedPreferencesProvider)
        .setDouble(_searchRadiusKey, radiusInMeters);
    state = radiusInMeters;
  }
}

final NotifierProvider<SearchRadiusNotifier, double> searchRadiusProvider =
    NotifierProvider<SearchRadiusNotifier, double>(SearchRadiusNotifier.new);
