import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/data/commons_urls.dart';

void main() {
  group('commonsFilePathUrl', () {
    test('builds a Special:FilePath URL with the given width', () {
      expect(
        commonsFilePathUrl('City court.jpg'),
        'https://commons.wikimedia.org/wiki/Special:FilePath/'
        'City%20court.jpg?width=800',
      );
    });

    test('honors a custom width', () {
      expect(
        commonsFilePathUrl('Court.jpg', width: 200),
        'https://commons.wikimedia.org/wiki/Special:FilePath/Court.jpg'
        '?width=200',
      );
    });
  });

  group('commonsFileTitleFromUrl', () {
    test('round-trips a URL built by commonsFilePathUrl', () {
      final url = commonsFilePathUrl('City court.jpg');
      expect(commonsFileTitleFromUrl(url), 'City court.jpg');
    });

    test('extracts the title from an upload.wikimedia.org URL', () {
      expect(
        commonsFileTitleFromUrl(
          'https://upload.wikimedia.org/wikipedia/commons/a/ab/Court.jpg',
        ),
        'Court.jpg',
      );
    });

    test('extracts the title from a Commons wiki File: page URL', () {
      expect(
        commonsFileTitleFromUrl(
          'https://commons.wikimedia.org/wiki/File:Court.jpg',
        ),
        'Court.jpg',
      );
    });

    test('returns null for a URL from anywhere else', () {
      expect(
        commonsFileTitleFromUrl('https://example.com/photos/court.jpg'),
        isNull,
      );
    });
  });
}
