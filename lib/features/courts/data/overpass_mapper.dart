import '../domain/court.dart';
import 'commons_urls.dart';

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
    name: (tags['name'] as String?) ?? 'Basketball court',
    latitude: coordinates.$1,
    longitude: coordinates.$2,
    hoopCount: _hoopCountOf(tags),
    isOutdoor: _isOutdoorOf(tags),
    createdAt: DateTime.now(),
    imageUrl: _imageUrlOf(tags),
  );
}

/// Only ever returns a Wikimedia Commons URL, resolved from the
/// `wikimedia_commons` tag or a Commons-hosted `image` tag: it's the only
/// source this app can pair with a fetchable author/license (see
/// data/commons_attribution.dart), which display of the photo requires.
/// A bare `image=*` URL pointing anywhere else is ignored on purpose —
/// there is no generic way to get a legally sufficient attribution for it.
String? _imageUrlOf(Map<String, dynamic> tags) {
  final commonsTag = tags['wikimedia_commons'];
  if (commonsTag is String && commonsTag.startsWith('File:')) {
    return commonsFilePathUrl(commonsTag.substring('File:'.length));
  }

  final imageTag = tags['image'];
  if (imageTag is String) {
    final fileTitle = commonsFileTitleFromUrl(imageTag);
    if (fileTitle != null) {
      return commonsFilePathUrl(fileTitle);
    }
  }

  return null;
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
