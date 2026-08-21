import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/data/overpass_mapper.dart';

void main() {
  group('courtFromOverpassElement imageUrl', () {
    test('resolves a wikimedia_commons File: tag to a direct URL', () {
      final court = courtFromOverpassElement({
        'type': 'node',
        'id': 1,
        'lat': 48.85,
        'lon': 2.35,
        'tags': {'wikimedia_commons': 'File:City court.jpg'},
      });

      expect(
        court?.imageUrl,
        'https://commons.wikimedia.org/wiki/Special:FilePath/'
        'City%20court.jpg?width=800',
      );
    });

    test('ignores a wikimedia_commons Category: tag (ambiguous)', () {
      final court = courtFromOverpassElement({
        'type': 'node',
        'id': 1,
        'lat': 48.85,
        'lon': 2.35,
        'tags': {'wikimedia_commons': 'Category:Basketball courts'},
      });

      expect(court?.imageUrl, isNull);
    });

    test('resolves a Commons-hosted image tag to a direct URL', () {
      final court = courtFromOverpassElement({
        'type': 'node',
        'id': 1,
        'lat': 48.85,
        'lon': 2.35,
        'tags': {'image': 'https://commons.wikimedia.org/wiki/File:Court.jpg'},
      });

      expect(
        court?.imageUrl,
        'https://commons.wikimedia.org/wiki/Special:FilePath/Court.jpg'
        '?width=800',
      );
    });

    test('ignores an image tag pointing anywhere else', () {
      final court = courtFromOverpassElement({
        'type': 'node',
        'id': 1,
        'lat': 48.85,
        'lon': 2.35,
        'tags': {'image': 'https://example.com/photos/court.jpg'},
      });

      expect(court?.imageUrl, isNull);
    });

    test('is null when there is no image-related tag at all', () {
      final court = courtFromOverpassElement({
        'type': 'node',
        'id': 1,
        'lat': 48.85,
        'lon': 2.35,
        'tags': {'leisure': 'pitch', 'sport': 'basketball'},
      });

      expect(court?.imageUrl, isNull);
    });
  });
}
