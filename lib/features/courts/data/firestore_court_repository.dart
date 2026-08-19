import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/court.dart';
import '../domain/court_repository.dart';
import '../domain/geo_bounds.dart';
import 'court_mapper.dart';

class FirestoreCourtRepository implements CourtRepository {
  FirestoreCourtRepository({
    required FirebaseFirestore firestore,
    String? Function()? currentUserId,
  }) : _firestore = firestore,
       _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFirestore _firestore;
  final String? Function() _currentUserId;

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) {
    return _firestore
        .collection('courts')
        .where('lat', isGreaterThanOrEqualTo: bounds.minLat)
        .where('lat', isLessThanOrEqualTo: bounds.maxLat)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(courtFromSnapshot)
              .where(
                (court) =>
                    court.longitude >= bounds.minLng &&
                    court.longitude <= bounds.maxLng,
              )
              .toList(),
        );
  }

  @override
  Stream<Court> watchCourt(String id) {
    if (id.startsWith('osm:')) {
      return Stream.error(CourtNotFoundException(id));
    }

    return _firestore.collection('courts').doc(id).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw CourtNotFoundException(id);
      }
      return courtFromSnapshot(snapshot);
    });
  }

  @override
  Future<String> addCourt(Court court) async {
    final docRef = await _firestore.collection('courts').add({
      'name': court.name,
      'location': GeoPoint(court.latitude, court.longitude),
      'lat': court.latitude,
      'lng': court.longitude,
      'hoopCount': court.hoopCount,
      'isOutdoor': court.isOutdoor,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _currentUserId(),
    });
    return docRef.id;
  }
}
