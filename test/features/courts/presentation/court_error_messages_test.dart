import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/features/courts/data/overpass_court_repository.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/presentation/court_error_messages.dart';

void main() {
  group('courtErrorMessage', () {
    test('gives a specific message for a denied location permission', () {
      expect(
        courtErrorMessage(const LocationPermissionDeniedException()),
        contains('position'),
      );
    });

    test('gives a specific message for a disabled location service', () {
      expect(
        courtErrorMessage(const LocationServiceDisabledException()),
        contains('désactivée'),
      );
    });

    test('gives a specific message for an Overpass rate limit', () {
      expect(
        courtErrorMessage(OverpassRateLimitedException()),
        contains('sollicité'),
      );
    });

    test('gives a specific message for an area that is too large', () {
      expect(courtErrorMessage(AreaTooLargeException(30)), contains('grande'));
    });

    test('gives a specific message for a generic Overpass failure', () {
      expect(
        courtErrorMessage(OverpassException('boom')),
        contains('OpenStreetMap'),
      );
    });

    test('gives a specific message for a missing court', () {
      expect(
        courtErrorMessage(CourtNotFoundException('court-1')),
        contains('introuvable'),
      );
    });

    test('falls back to a generic message for an unrecognized error', () {
      expect(
        courtErrorMessage(Exception('anything else')),
        'Une erreur inattendue est survenue. Réessayez.',
      );
    });
  });

  group('courtErrorIcon', () {
    test('uses a location icon for location-related errors', () {
      expect(
        courtErrorIcon(const LocationPermissionDeniedException()),
        Icons.location_off_rounded,
      );
      expect(
        courtErrorIcon(const LocationServiceDisabledException()),
        Icons.location_off_rounded,
      );
    });

    test('uses a search icon for a missing court', () {
      expect(
        courtErrorIcon(CourtNotFoundException('court-1')),
        Icons.search_off,
      );
    });

    test('falls back to a network icon for everything else', () {
      expect(courtErrorIcon(OverpassException('boom')), Icons.wifi_off_rounded);
      expect(
        courtErrorIcon(Exception('anything else')),
        Icons.wifi_off_rounded,
      );
    });
  });
}
