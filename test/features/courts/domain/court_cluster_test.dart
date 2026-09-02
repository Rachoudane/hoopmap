import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_cluster.dart';
import 'package:hoopmap/features/courts/domain/court_with_distance.dart';

CourtWithDistance _court(
  String id,
  double latitude,
  double longitude, {
  double distanceInMeters = 0,
}) => CourtWithDistance(
  court: Court(
    id: id,
    name: id,
    latitude: latitude,
    longitude: longitude,
    hoopCount: 1,
    isOutdoor: true,
    createdAt: DateTime(2026, 1, 1),
  ),
  distanceInMeters: distanceInMeters,
);

void main() {
  group('clusterCourts', () {
    test('nothing to cluster yields nothing', () {
      expect(clusterCourts(const [], zoom: 13), isEmpty);
    });

    test('a court on its own stays a single marker at its own position', () {
      final clusters = clusterCourts([_court('a', 48.8566, 2.3522)], zoom: 13);

      expect(clusters, hasLength(1));
      expect(clusters.single.isSingle, isTrue);
      expect(clusters.single.single.court.id, 'a');
      expect(clusters.single.latitude, closeTo(48.8566, 0.0001));
      expect(clusters.single.longitude, closeTo(2.3522, 0.0001));
    });

    test('courts metres apart become one marker holding all of them', () {
      final clusters = clusterCourts([
        _court('a', 48.8566, 2.3522),
        _court('b', 48.8567, 2.3523),
        _court('c', 48.8568, 2.3521),
      ], zoom: 13);

      expect(clusters, hasLength(1));
      expect(clusters.single.courts, hasLength(3));
      expect(clusters.single.isSingle, isFalse);
    });

    test('a cluster sits at the middle of the courts it holds', () {
      final clusters = clusterCourts([
        _court('a', 10, 20),
        _court('b', 10.0002, 20.0004),
      ], zoom: 13);

      expect(clusters.single.latitude, closeTo(10.0001, 0.00001));
      expect(clusters.single.longitude, closeTo(20.0002, 0.00001));
    });

    test('zooming in splits a cluster apart', () {
      final courts = [_court('a', 0, 0), _court('b', 0, 0.01)];

      // The same courts, the same call: only the zoom decides whether they
      // overlap on screen.
      expect(clusterCourts(courts, zoom: 10), hasLength(1));
      expect(clusterCourts(courts, zoom: 16), hasLength(2));
    });

    test('every court ends up in exactly one cluster, whatever the zoom', () {
      final courts = [
        for (var i = 0; i < 40; i++) _court('court-$i', i * 0.002, i * 0.003),
      ];

      for (final zoom in [8.0, 11.0, 13.5, 16.0, 18.0]) {
        final clustered = clusterCourts(courts, zoom: zoom);
        final ids = [
          for (final cluster in clustered)
            for (final court in cluster.courts) court.court.id,
        ];

        expect(ids, hasLength(courts.length), reason: 'at zoom $zoom');
        expect(ids.toSet(), hasLength(courts.length), reason: 'at zoom $zoom');
      }
    });

    test('clusters come back in the order the courts were given, so the '
        'nearest still leads', () {
      final clusters = clusterCourts([
        _court('near', 0, 0, distanceInMeters: 100),
        _court('far', 1, 1, distanceInMeters: 5000),
      ], zoom: 13);

      expect(clusters.map((c) => c.courts.first.court.id).toList(), [
        'near',
        'far',
      ]);
    });

    test('grouping follows the world, not the courts it is given', () {
      // The same two courts, reached from opposite directions: a grid
      // anchored to the viewport would group them one way and then the
      // other, making clusters flicker as the user pans.
      final courts = [_court('a', 0.001, 0.001), _court('b', 0.002, 0.002)];
      final reversed = courts.reversed.toList();

      expect(
        clusterCourts(courts, zoom: 13).length,
        clusterCourts(reversed, zoom: 13).length,
      );
    });

    test('a cluster is identified by the courts it holds', () {
      final clusters = clusterCourts([
        _court('a', 0, 0),
        _court('b', 0.0001, 0.0001),
      ], zoom: 13);

      expect(clusters.single.id, 'a+b');
    });

    test('courts near the poles cluster without blowing up the projection', () {
      final clusters = clusterCourts([
        _court('north', 89.9, 0),
        _court('south', -89.9, 0),
      ], zoom: 13);

      expect(clusters, hasLength(2));
      for (final cluster in clusters) {
        expect(cluster.latitude.isFinite, isTrue);
        expect(cluster.longitude.isFinite, isTrue);
      }
    });
  });
}
