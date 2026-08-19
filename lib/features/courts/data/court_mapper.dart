import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/court.dart';

class CourtMappingException implements Exception {
  CourtMappingException(this.message);

  final String message;

  @override
  String toString() => 'CourtMappingException: $message';
}

Court courtFromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
  final data = snapshot.data();
  if (data == null) {
    throw CourtMappingException('Document ${snapshot.id} has no data.');
  }

  final name = _requireField<String>(data, snapshot.id, 'name');
  final hoopCount = _requireField<int>(data, snapshot.id, 'hoopCount');
  final isOutdoor = _requireField<bool>(data, snapshot.id, 'isOutdoor');
  final createdAt = _requireField<Timestamp>(data, snapshot.id, 'createdAt');
  final coordinates = _coordinatesOf(data, snapshot.id);

  return Court(
    id: snapshot.id,
    name: name,
    latitude: coordinates.$1,
    longitude: coordinates.$2,
    hoopCount: hoopCount,
    isOutdoor: isOutdoor,
    createdAt: createdAt.toDate(),
  );
}

(double, double) _coordinatesOf(Map<String, dynamic> data, String documentId) {
  final lat = data['lat'];
  final lng = data['lng'];
  if (lat is num && lng is num) {
    return (lat.toDouble(), lng.toDouble());
  }

  final location = _requireField<GeoPoint>(data, documentId, 'location');
  return (location.latitude, location.longitude);
}

T _requireField<T>(Map<String, dynamic> data, String documentId, String key) {
  if (!data.containsKey(key)) {
    throw CourtMappingException(
      'Document $documentId is missing required field "$key".',
    );
  }
  final value = data[key];
  if (value is! T) {
    throw CourtMappingException(
      'Document $documentId has field "$key" of type '
      '${value.runtimeType}, expected $T.',
    );
  }
  return value;
}
