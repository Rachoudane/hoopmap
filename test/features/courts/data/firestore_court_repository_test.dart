import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/data/court_mapper.dart';
import 'package:hoopmap/features/courts/data/firestore_court_repository.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';

void main() {
  group('FirestoreCourtRepository.watchCourtsInBounds', () {
    final bounds = GeoBounds.aroundPoint(48.8566, 2.3522, 5000);

    test('returns a document that falls inside the bounds', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('courts').doc('inside').set({
        'name': 'Terrain Central',
        'location': const GeoPoint(48.8566, 2.3522),
        'lat': 48.8566,
        'lng': 2.3522,
        'hoopCount': 2,
        'isOutdoor': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      final repository = FirestoreCourtRepository(firestore: firestore);

      final courts = await repository.watchCourtsInBounds(bounds).first;

      expect(courts.map((c) => c.id).toList(), ['inside']);
    });

    test('excludes a document outside the bounds in longitude', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('courts').doc('inside').set({
        'name': 'Terrain Central',
        'location': const GeoPoint(48.8566, 2.3522),
        'lat': 48.8566,
        'lng': 2.3522,
        'hoopCount': 2,
        'isOutdoor': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      await firestore.collection('courts').doc('outside').set({
        'name': 'Terrain Lointain',
        'location': const GeoPoint(48.8566, 10.0),
        'lat': 48.8566,
        'lng': 10.0,
        'hoopCount': 2,
        'isOutdoor': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      final repository = FirestoreCourtRepository(firestore: firestore);

      final courts = await repository.watchCourtsInBounds(bounds).first;

      expect(courts.map((c) => c.id).toList(), ['inside']);
    });

    test(
      'currently propagates a mapping error and loses the whole list',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('courts').doc('court-1').set({
          'name': 'Terrain A',
          'location': const GeoPoint(48.8566, 2.3522),
          'lat': 48.8566,
          'lng': 2.3522,
          'hoopCount': 2,
          'isOutdoor': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });
        await firestore.collection('courts').doc('court-2').set({
          'location': const GeoPoint(48.8566, 2.3522),
          'lat': 48.8566,
          'lng': 2.3522,
          'hoopCount': 4,
          'isOutdoor': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
        });
        final repository = FirestoreCourtRepository(firestore: firestore);

        await expectLater(
          repository.watchCourtsInBounds(bounds),
          emitsError(isA<CourtMappingException>()),
        );
      },
    );

    test('emits a new list when a document is added while listening', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreCourtRepository(firestore: firestore);

      final expectation = expectLater(
        repository.watchCourtsInBounds(bounds),
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
        'lat': 48.8566,
        'lng': 2.3522,
        'hoopCount': 2,
        'isOutdoor': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      await expectation;
    });
  });

  group('FirestoreCourtRepository.watchCourt', () {
    test('returns the Court for an existing document', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('courts').doc('court-1').set({
        'name': 'Terrain A',
        'location': const GeoPoint(48.8566, 2.3522),
        'lat': 48.8566,
        'lng': 2.3522,
        'hoopCount': 3,
        'isOutdoor': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      final repository = FirestoreCourtRepository(firestore: firestore);

      final court = await repository.watchCourt('court-1').first;

      expect(court.id, 'court-1');
      expect(court.name, 'Terrain A');
      expect(court.hoopCount, 3);
    });

    test('throws CourtNotFoundException for a missing document', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreCourtRepository(firestore: firestore);

      await expectLater(
        repository.watchCourt('missing'),
        emitsError(isA<CourtNotFoundException>()),
      );
    });

    test('throws CourtNotFoundException for an "osm:" prefixed id without a '
        'request', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreCourtRepository(firestore: firestore);

      await expectLater(
        repository.watchCourt('osm:way-1'),
        emitsError(isA<CourtNotFoundException>()),
      );
    });
  });

  group('FirestoreCourtRepository.addCourt', () {
    test('creates a document with all expected fields, including lat, lng '
        'and createdBy', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreCourtRepository(
        firestore: firestore,
        currentUserId: () => 'user-42',
      );
      final court = Court(
        id: '',
        name: 'Terrain Ajouté',
        latitude: 48.8566,
        longitude: 2.3522,
        hoopCount: 3,
        isOutdoor: true,
        createdAt: DateTime(2026, 1, 1),
      );

      final id = await repository.addCourt(court);

      final snapshot = await firestore.collection('courts').doc(id).get();
      expect(snapshot.exists, true);
      final data = snapshot.data()!;
      expect(data['name'], 'Terrain Ajouté');
      expect(data['lat'], 48.8566);
      expect(data['lng'], 2.3522);
      expect(data['location'], const GeoPoint(48.8566, 2.3522));
      expect(data['hoopCount'], 3);
      expect(data['isOutdoor'], true);
      expect(data['createdBy'], 'user-42');
      expect(data['createdAt'], isA<Timestamp>());
    });
  });
}
