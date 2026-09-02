/// A place the user can browse courts from without giving up their location.
class City {
  const City({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;

  /// Stable enough to persist and to match a stored choice back to this list.
  String get id => '$name, $country';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is City && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// The cities offered as a starting point, with their rough centres.
///
/// Bundled rather than geocoded: a search box that needs a network round trip
/// (and someone else's rate limit) to answer "Lyon" would fail in exactly the
/// situation this list exists for — no location, poor connection, an app that
/// has to be useful anyway. The list is deliberately not exhaustive; the map
/// is what covers everywhere else, and the picker says so.
const List<City> browsableCities = [
  City(name: 'Paris', country: 'France', latitude: 48.8566, longitude: 2.3522),
  City(name: 'Lyon', country: 'France', latitude: 45.7640, longitude: 4.8357),
  City(
    name: 'Marseille',
    country: 'France',
    latitude: 43.2965,
    longitude: 5.3698,
  ),
  City(
    name: 'Toulouse',
    country: 'France',
    latitude: 43.6047,
    longitude: 1.4442,
  ),
  City(name: 'Lille', country: 'France', latitude: 50.6292, longitude: 3.0573),
  City(
    name: 'Bordeaux',
    country: 'France',
    latitude: 44.8378,
    longitude: -0.5792,
  ),
  City(
    name: 'Nantes',
    country: 'France',
    latitude: 47.2184,
    longitude: -1.5536,
  ),
  City(name: 'Nice', country: 'France', latitude: 43.7102, longitude: 7.2620),
  City(
    name: 'Brussels',
    country: 'Belgium',
    latitude: 50.8503,
    longitude: 4.3517,
  ),
  City(
    name: 'London',
    country: 'United Kingdom',
    latitude: 51.5074,
    longitude: -0.1278,
  ),
  City(name: 'Madrid', country: 'Spain', latitude: 40.4168, longitude: -3.7038),
  City(
    name: 'Barcelona',
    country: 'Spain',
    latitude: 41.3874,
    longitude: 2.1686,
  ),
  City(
    name: 'Lisbon',
    country: 'Portugal',
    latitude: 38.7223,
    longitude: -9.1393,
  ),
  City(name: 'Rome', country: 'Italy', latitude: 41.9028, longitude: 12.4964),
  City(name: 'Milan', country: 'Italy', latitude: 45.4642, longitude: 9.1900),
  City(
    name: 'Berlin',
    country: 'Germany',
    latitude: 52.5200,
    longitude: 13.4050,
  ),
  City(
    name: 'Munich',
    country: 'Germany',
    latitude: 48.1351,
    longitude: 11.5820,
  ),
  City(
    name: 'Amsterdam',
    country: 'Netherlands',
    latitude: 52.3676,
    longitude: 4.9041,
  ),
  City(
    name: 'Zurich',
    country: 'Switzerland',
    latitude: 47.3769,
    longitude: 8.5417,
  ),
  City(
    name: 'Vienna',
    country: 'Austria',
    latitude: 48.2082,
    longitude: 16.3738,
  ),
  City(
    name: 'Warsaw',
    country: 'Poland',
    latitude: 52.2297,
    longitude: 21.0122,
  ),
  City(
    name: 'Athens',
    country: 'Greece',
    latitude: 37.9838,
    longitude: 23.7275,
  ),
  City(
    name: 'Istanbul',
    country: 'Türkiye',
    latitude: 41.0082,
    longitude: 28.9784,
  ),
  City(
    name: 'New York',
    country: 'United States',
    latitude: 40.7128,
    longitude: -74.0060,
  ),
  City(
    name: 'Los Angeles',
    country: 'United States',
    latitude: 34.0522,
    longitude: -118.2437,
  ),
  City(
    name: 'Chicago',
    country: 'United States',
    latitude: 41.8781,
    longitude: -87.6298,
  ),
  City(
    name: 'Miami',
    country: 'United States',
    latitude: 25.7617,
    longitude: -80.1918,
  ),
  City(
    name: 'Toronto',
    country: 'Canada',
    latitude: 43.6532,
    longitude: -79.3832,
  ),
  City(
    name: 'Montreal',
    country: 'Canada',
    latitude: 45.5019,
    longitude: -73.5674,
  ),
  City(
    name: 'Mexico City',
    country: 'Mexico',
    latitude: 19.4326,
    longitude: -99.1332,
  ),
  City(
    name: 'São Paulo',
    country: 'Brazil',
    latitude: -23.5505,
    longitude: -46.6333,
  ),
  City(
    name: 'Buenos Aires',
    country: 'Argentina',
    latitude: -34.6037,
    longitude: -58.3816,
  ),
  City(
    name: 'Dakar',
    country: 'Senegal',
    latitude: 14.7167,
    longitude: -17.4677,
  ),
  City(
    name: 'Casablanca',
    country: 'Morocco',
    latitude: 33.5731,
    longitude: -7.5898,
  ),
  City(
    name: 'Johannesburg',
    country: 'South Africa',
    latitude: -26.2041,
    longitude: 28.0473,
  ),
  City(name: 'Cairo', country: 'Egypt', latitude: 30.0444, longitude: 31.2357),
  City(
    name: 'Dubai',
    country: 'United Arab Emirates',
    latitude: 25.2048,
    longitude: 55.2708,
  ),
  City(name: 'Tokyo', country: 'Japan', latitude: 35.6762, longitude: 139.6503),
  City(
    name: 'Seoul',
    country: 'South Korea',
    latitude: 37.5665,
    longitude: 126.9780,
  ),
  City(
    name: 'Manila',
    country: 'Philippines',
    latitude: 14.5995,
    longitude: 120.9842,
  ),
  City(
    name: 'Sydney',
    country: 'Australia',
    latitude: -33.8688,
    longitude: 151.2093,
  ),
  City(
    name: 'Melbourne',
    country: 'Australia',
    latitude: -37.8136,
    longitude: 144.9631,
  ),
];

/// The cities whose name or country matches [query], in list order.
///
/// Matching on the country too is what makes a list this short usable: a
/// user who doesn't find their own town can type their country and see which
/// nearby city is offered.
List<City> searchCities(String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return browsableCities;

  return [
    for (final city in browsableCities)
      if (city.name.toLowerCase().contains(normalized) ||
          city.country.toLowerCase().contains(normalized))
        city,
  ];
}
