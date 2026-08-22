import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/data/court_mapper.dart';
import 'package:hoopmap/features/courts/domain/court.dart';

void main() {
  group('courtFromSnapshot', () {
    test('maps a complete valid document to the expected Court', () async {
      final firestore = FakeFirebaseFirestore();
      final createdAt = DateTime(2026, 1, 15, 10, 30);
      await firestore.collection('courts').doc('court-1').set({
        'name': 'Court Central',
        'location': const GeoPoint(48.8566, 2.3522),
        'hoopCount': 4,
        'isOutdoor': true,
        'createdAt': Timestamp.fromDate(createdAt),
      });

      final snapshot = await firestore
          .collection('courts')
          .doc('court-1')
          .get();

      final court = courtFromSnapshot(snapshot);

      expect(
        court,
        Court(
          id: 'court-1',
          name: 'Court Central',
          latitude: 48.8566,
          longitude: 2.3522,
          hoopCount: 4,
          isOutdoor: true,
          createdAt: createdAt,
        ),
      );
    });

    test(
      'resolves a Commons wiki page imageUrl to a Special:FilePath URL',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('courts').doc('court-1').set({
          'name': 'Court Central',
          'location': const GeoPoint(48.8566, 2.3522),
          'hoopCount': 4,
          'isOutdoor': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
          'imageUrl': 'https://commons.wikimedia.org/wiki/File:Court.jpg',
        });

        final snapshot = await firestore
            .collection('courts')
            .doc('court-1')
            .get();

        final court = courtFromSnapshot(snapshot);

        expect(
          court.imageUrl,
          'https://commons.wikimedia.org/wiki/Special:FilePath/Court.jpg'
          '?width=800',
        );
      },
    );

    test(
      'ignores an imageUrl that is not resolvable to a Commons file',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('courts').doc('court-1').set({
          'name': 'Court Central',
          'location': const GeoPoint(48.8566, 2.3522),
          'hoopCount': 4,
          'isOutdoor': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
          'imageUrl': 'https://example.com/random-photo.jpg',
        });

        final snapshot = await firestore
            .collection('courts')
            .doc('court-1')
            .get();

        final court = courtFromSnapshot(snapshot);

        expect(court.imageUrl, isNull);
      },
    );

    test('throws CourtMappingException when name is missing', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('courts').doc('court-1').set({
        'location': const GeoPoint(48.8566, 2.3522),
        'hoopCount': 4,
        'isOutdoor': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
      });

      final snapshot = await firestore
          .collection('courts')
          .doc('court-1')
          .get();

      expect(
        () => courtFromSnapshot(snapshot),
        throwsA(isA<CourtMappingException>()),
      );
    });

    test(
      'throws CourtMappingException when location is not a GeoPoint',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('courts').doc('court-1').set({
          'name': 'Court Central',
          'location': 'not-a-geopoint',
          'hoopCount': 4,
          'isOutdoor': true,
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        });

        final snapshot = await firestore
            .collection('courts')
            .doc('court-1')
            .get();

        expect(
          () => courtFromSnapshot(snapshot),
          throwsA(isA<CourtMappingException>()),
        );
      },
    );
  });
}
