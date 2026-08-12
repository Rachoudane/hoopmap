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
  final location = _requireField<GeoPoint>(data, snapshot.id, 'location');
  final hoopCount = _requireField<int>(data, snapshot.id, 'hoopCount');
  final isOutdoor = _requireField<bool>(data, snapshot.id, 'isOutdoor');
  final createdAt = _requireField<Timestamp>(data, snapshot.id, 'createdAt');

  return Court(
    id: snapshot.id,
    name: name,
    latitude: location.latitude,
    longitude: location.longitude,
    hoopCount: hoopCount,
    isOutdoor: isOutdoor,
    createdAt: createdAt.toDate(),
  );
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
