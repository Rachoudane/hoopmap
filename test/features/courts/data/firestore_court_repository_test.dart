import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/data/court_mapper.dart';
import 'package:hoopmap/features/courts/data/firestore_court_repository.dart';
import 'package:hoopmap/features/courts/domain/court.dart';

void main() {
  group('FirestoreCourtRepository.watchCourts', () {
    test('emits two courts when two documents exist', () async {
      final firestore = FakeFirebaseFirestore();
      final court1CreatedAt = DateTime(2026, 1, 1);
      await firestore.collection('courts').doc('court-1').set({
        'name': 'Terrain A',
        'location': const GeoPoint(48.8566, 2.3522),
        'hoopCount': 2,
        'isOutdoor': true,
        'createdAt': Timestamp.fromDate(court1CreatedAt),
      });
      await firestore.collection('courts').doc('court-2').set({
        'name': 'Terrain B',
        'location': const GeoPoint(45.764, 4.8357),
        'hoopCount': 4,
        'isOutdoor': false,
        'createdAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
      });
      final repository = FirestoreCourtRepository(firestore: firestore);

      final courts = await repository.watchCourts().first;

      expect(courts, hasLength(2));
      final court1 = courts.singleWhere((court) => court.id == 'court-1');
      expect(court1.name, 'Terrain A');
      expect(court1.latitude, 48.8566);
      expect(court1.longitude, 2.3522);
      expect(court1.hoopCount, 2);
      expect(court1.isOutdoor, true);
      expect(court1.createdAt, court1CreatedAt);
    });

    test('emits an empty list when the collection is empty', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreCourtRepository(firestore: firestore);

      final courts = await repository.watchCourts().first;

      expect(courts, isEmpty);
    });

    test('emits a new list when a document is added while listening', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreCourtRepository(firestore: firestore);

      final expectation = expectLater(
        repository.watchCourts(),
        emitsInOrder([
          isEmpty,
          predicate<List<Court>>(
            (courts) => courts.length == 1 && courts.single.id == 'court-1',
          ),
        ]),
      );

      await firestore.collection('courts').doc('court-1').set({
        'name': 'Terrain A',
        'location': const GeoPoint(48.8566, 2.3522),
        'hoopCount': 2,
        'isOutdoor': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      await expectation;
    });

    test(
      'currently propagates a mapping error and loses the whole list',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('courts').doc('court-1').set({
          'name': 'Terrain A',
          'location': const GeoPoint(48.8566, 2.3522),
          'hoopCount': 2,
          'isOutdoor': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });
        await firestore.collection('courts').doc('court-2').set({
          'location': const GeoPoint(45.764, 4.8357),
          'hoopCount': 4,
          'isOutdoor': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
        });
        final repository = FirestoreCourtRepository(firestore: firestore);

        await expectLater(
          repository.watchCourts(),
          emitsError(isA<CourtMappingException>()),
        );
      },
    );
  });
}
