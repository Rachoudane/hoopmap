import '../domain/court.dart';

Court? courtFromOverpassElement(Map<String, dynamic> element) {
  final type = element['type'] as String?;
  final id = element['id'];
  if (type == null || id == null) return null;

  final coordinates = _coordinatesOf(element);
  if (coordinates == null) return null;

  final tagsRaw = element['tags'];
  final tags = tagsRaw is Map<String, dynamic>
      ? tagsRaw
      : const <String, dynamic>{};

  return Court(
    id: 'osm:$type-$id',
    name: (tags['name'] as String?) ?? 'Terrain de basket',
    latitude: coordinates.$1,
    longitude: coordinates.$2,
    hoopCount: _hoopCountOf(tags),
    isOutdoor: _isOutdoorOf(tags),
    createdAt: DateTime.now(),
  );
}

(double, double)? _coordinatesOf(Map<String, dynamic> element) {
  final lat = element['lat'];
  final lon = element['lon'];
  if (lat is num && lon is num) {
    return (lat.toDouble(), lon.toDouble());
  }

  final center = element['center'];
  if (center is Map<String, dynamic>) {
    final centerLat = center['lat'];
    final centerLon = center['lon'];
    if (centerLat is num && centerLon is num) {
      return (centerLat.toDouble(), centerLon.toDouble());
    }
  }

  return null;
}

int _hoopCountOf(Map<String, dynamic> tags) {
  final hoops = tags['hoops'];
  if (hoops is int) return hoops;
  if (hoops is String) {
    final parsed = int.tryParse(hoops);
    if (parsed != null) return parsed;
  }
  return 2;
}

bool _isOutdoorOf(Map<String, dynamic> tags) {
  if (tags['indoor'] == 'yes') return false;
  if (tags.containsKey('building')) return false;
  return true;
}
