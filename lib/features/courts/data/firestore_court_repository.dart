import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/court.dart';
import '../domain/court_repository.dart';
import 'court_mapper.dart';

class FirestoreCourtRepository implements CourtRepository {
  FirestoreCourtRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Court>> watchCourts() {
    return _firestore
        .collection('courts')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(courtFromSnapshot).toList());
  }
}
