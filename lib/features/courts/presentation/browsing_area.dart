import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browse_city_provider.dart';
import 'map_courts_provider.dart';

/// Where the app is showing courts for, when that isn't the user's own
/// surroundings: the city they picked, or the box they panned the map to.
///
/// Null means "wherever the user is" — the app's default, and the only case
/// where a position is involved at all.
class BrowsingArea {
  const BrowsingArea({
    required this.latitude,
    required this.longitude,
    this.cityName,
  });

  final double latitude;
  final double longitude;

  /// The city's name when the area came from the picker, so a screen can say
  /// where it means instead of "here". Null for a panned map, which has no
  /// name to give.
  final String? cityName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BrowsingArea &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.cityName == cityName);

  @override
  int get hashCode => Object.hash(latitude, longitude, cityName);
}

/// The one answer to "where is the user looking?", for the screens that need
/// a centre without asking for a location.
///
/// A picked city wins over a panned map for the same reason it wins over the
/// device's position: it is the more explicit statement of intent, and it is
/// what the map itself moves to.
final Provider<BrowsingArea?> browsingAreaProvider = Provider<BrowsingArea?>((
  ref,
) {
  final city = ref.watch(browseCityProvider);
  if (city != null) {
    return BrowsingArea(
      latitude: city.latitude,
      longitude: city.longitude,
      cityName: city.name,
    );
  }

  final bounds = ref.watch(visibleMapBoundsProvider);
  if (bounds != null) {
    return BrowsingArea(
      latitude: bounds.centerLat,
      longitude: bounds.centerLng,
    );
  }

  return null;
});
