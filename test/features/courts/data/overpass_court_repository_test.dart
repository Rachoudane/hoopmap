import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/data/overpass_court_repository.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:http/http.dart' as http;

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;
  int requestCount = 0;
  final List<Uri> requestedUrls = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requestCount++;
    requestedUrls.add(request.url);
    return _handler(request);
  }
}

/// Endpoints a test can tell apart, standing in for the real instances.
final _instances = [
  Uri.parse('https://first.example/api/interpreter'),
  Uri.parse('https://second.example/api/interpreter'),
  Uri.parse('https://third.example/api/interpreter'),
];

/// Records the backoff instead of living through it, so the retry tests
/// assert the waits rather than spend them.
class _RecordingClock {
  final List<Duration> waits = [];

  Future<void> wait(Duration duration) async => waits.add(duration);
}

http.StreamedResponse _response(String body, {int statusCode = 200}) {
  return http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);
}

void main() {
  final bounds = GeoBounds.aroundPoint(48.8566, 2.3522, 1000);

  group('OverpassCourtRepository.watchCourtsInBounds', () {
    test('maps a node and a way from the Overpass response', () async {
      final responseBody = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 111,
            'lat': 48.85,
            'lon': 2.35,
            'tags': {
              'leisure': 'pitch',
              'sport': 'basketball',
              'name': 'City Court',
              'hoops': '4',
            },
          },
          {
            'type': 'way',
            'id': 222,
            'center': {'lat': 48.86, 'lon': 2.36},
            'tags': {
              'leisure': 'pitch',
              'sport': 'basketball',
              'indoor': 'yes',
            },
          },
        ],
      });
      final client = _FakeHttpClient(
        (request) async => _response(responseBody),
      );
      final repository = OverpassCourtRepository(httpClient: client);

      final courts = await repository.watchCourtsInBounds(bounds).first;

      expect(courts, hasLength(2));

      final node = courts.singleWhere((c) => c.id == 'osm:node-111');
      expect(node.name, 'City Court');
      expect(node.latitude, 48.85);
      expect(node.longitude, 2.35);
      expect(node.hoopCount, 4);
      expect(node.isOutdoor, true);

      final way = courts.singleWhere((c) => c.id == 'osm:way-222');
      expect(way.name, 'Basketball court');
      expect(way.latitude, 48.86);
      expect(way.longitude, 2.36);
      expect(way.hoopCount, 2);
      expect(way.isOutdoor, false);
    });

    test('ignores an element without usable coordinates', () async {
      final responseBody = jsonEncode({
        'elements': [
          {
            'type': 'way',
            'id': 333,
            'tags': {'leisure': 'pitch', 'sport': 'basketball'},
          },
        ],
      });
      final client = _FakeHttpClient(
        (request) async => _response(responseBody),
      );
      final repository = OverpassCourtRepository(httpClient: client);

      final courts = await repository.watchCourtsInBounds(bounds).first;

      expect(courts, isEmpty);
    });

    test('throws OverpassException on a non-200 status code', () async {
      final client = _FakeHttpClient(
        (request) async => _response('server error', statusCode: 500),
      );
      final repository = OverpassCourtRepository(
        httpClient: client,
        wait: _RecordingClock().wait,
      );

      await expectLater(
        repository.watchCourtsInBounds(bounds),
        emitsError(isA<OverpassException>()),
      );
    });

    test('throws OverpassRateLimitedException on a 429 status code', () async {
      final client = _FakeHttpClient(
        (request) async => _response('rate limited', statusCode: 429),
      );
      final repository = OverpassCourtRepository(
        httpClient: client,
        wait: _RecordingClock().wait,
      );

      await expectLater(
        repository.watchCourtsInBounds(bounds),
        emitsError(isA<OverpassRateLimitedException>()),
      );
    });

    test('throws OverpassException when the underlying request fails (no '
        'network)', () async {
      final client = _FakeHttpClient(
        (request) async => throw const SocketException('Failed host lookup'),
      );
      final repository = OverpassCourtRepository(
        httpClient: client,
        wait: _RecordingClock().wait,
      );

      await expectLater(
        repository.watchCourtsInBounds(bounds),
        emitsError(isA<OverpassException>()),
      );
    });

    test('throws OverpassException on an unreadable response body', () async {
      final client = _FakeHttpClient((request) async => _response('not json'));
      final repository = OverpassCourtRepository(
        httpClient: client,
        wait: _RecordingClock().wait,
      );

      await expectLater(
        repository.watchCourtsInBounds(bounds),
        emitsError(isA<OverpassException>()),
      );
    });

    group('when an instance fails', () {
      test(
        'falls back to the next one, and stops as soon as one answers',
        () async {
          final client = _FakeHttpClient(
            (request) async => request.url == _instances[1]
                ? _response('{"elements": []}')
                : _response('down', statusCode: 503),
          );
          final clock = _RecordingClock();
          final repository = OverpassCourtRepository(
            httpClient: client,
            endpoints: _instances,
            wait: clock.wait,
          );

          await expectLater(
            repository.watchCourtsInBounds(bounds),
            emits(isEmpty),
          );
          expect(client.requestedUrls, [_instances[0], _instances[1]]);
        },
      );

      test('waits longer before each further attempt', () async {
        final client = _FakeHttpClient(
          (request) async => _response('down', statusCode: 503),
        );
        final clock = _RecordingClock();
        final repository = OverpassCourtRepository(
          httpClient: client,
          endpoints: _instances,
          firstRetryDelay: const Duration(milliseconds: 100),
          wait: clock.wait,
        );

        await expectLater(
          repository.watchCourtsInBounds(bounds),
          emitsError(isA<OverpassException>()),
        );
        // One wait between attempts, none after the last: a failure the user
        // is waiting on must not be padded with a delay that buys nothing.
        expect(clock.waits, [
          const Duration(milliseconds: 100),
          const Duration(milliseconds: 200),
        ]);
      });

      test('reports what the last attempt failed with', () async {
        final client = _FakeHttpClient(
          (request) async => request.url == _instances.last
              ? _response('rate limited', statusCode: 429)
              : _response('down', statusCode: 503),
        );
        final repository = OverpassCourtRepository(
          httpClient: client,
          endpoints: _instances,
          wait: _RecordingClock().wait,
        );

        await expectLater(
          repository.watchCourtsInBounds(bounds),
          emitsError(isA<OverpassRateLimitedException>()),
        );
      });

      test(
        'tries the rest after a rate limit rather than giving up on it',
        () async {
          final client = _FakeHttpClient(
            (request) async => request.url == _instances[0]
                ? _response('rate limited', statusCode: 429)
                : _response('{"elements": []}'),
          );
          final repository = OverpassCourtRepository(
            httpClient: client,
            endpoints: _instances,
            wait: _RecordingClock().wait,
          );

          await expectLater(
            repository.watchCourtsInBounds(bounds),
            emits(isEmpty),
          );
          expect(client.requestCount, 2);
        },
      );

      test('does not carry a rejected query to the next instance', () async {
        final client = _FakeHttpClient(
          (request) async => _response('bad request', statusCode: 400),
        );
        final repository = OverpassCourtRepository(
          httpClient: client,
          endpoints: _instances,
          wait: _RecordingClock().wait,
        );

        await expectLater(
          repository.watchCourtsInBounds(bounds),
          emitsError(isA<OverpassException>()),
        );
        // Every instance runs the same query and would reject it the same
        // way; asking them anyway just spends their quota.
        expect(client.requestCount, 1);
      });

      test(
        'starts the next search at the instance that answered last',
        () async {
          final client = _FakeHttpClient(
            (request) async => request.url == _instances[0]
                ? _response('down', statusCode: 503)
                : _response('{"elements": []}'),
          );
          final repository = OverpassCourtRepository(
            httpClient: client,
            endpoints: _instances,
            wait: _RecordingClock().wait,
          );

          await repository.watchCourtsInBounds(bounds).first;
          client.requestedUrls.clear();
          await repository.watchCourtsInBounds(bounds).first;

          // Starting over at an instance known to be down would pay its
          // timeout again on every single search.
          expect(client.requestedUrls, [_instances[1]]);
        },
      );

      test('a single court lookup falls back the same way', () async {
        final courtBody = jsonEncode({
          'elements': [
            {
              'type': 'node',
              'id': 1,
              'lat': 48.85,
              'lon': 2.35,
              'tags': {'leisure': 'pitch', 'sport': 'basketball'},
            },
          ],
        });
        final client = _FakeHttpClient(
          (request) async => request.url == _instances[0]
              ? _response('down', statusCode: 503)
              : _response(courtBody),
        );
        final repository = OverpassCourtRepository(
          httpClient: client,
          endpoints: _instances,
          wait: _RecordingClock().wait,
        );

        final court = await repository.watchCourt('osm:node-1').first;

        expect(court.id, 'osm:node-1');
        expect(client.requestCount, 2);
      });
    });

    test('throws AreaTooLargeException without sending a request when the box '
        'is too large', () async {
      final client = _FakeHttpClient(
        (request) async => _response('{"elements": []}'),
      );
      final repository = OverpassCourtRepository(httpClient: client);
      const hugeBounds = GeoBounds(
        minLat: -80,
        maxLat: 80,
        minLng: -170,
        maxLng: 170,
      );

      await expectLater(
        repository.watchCourtsInBounds(hugeBounds),
        emitsError(isA<AreaTooLargeException>()),
      );
      expect(client.requestCount, 0);
    });
  });

  group('OverpassCourtRepository.watchCourt', () {
    test('returns the Court for an "osm:node-1" id', () async {
      final responseBody = jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 1,
            'lat': 48.85,
            'lon': 2.35,
            'tags': {
              'leisure': 'pitch',
              'sport': 'basketball',
              'name': 'City Court',
              'hoops': '4',
            },
          },
        ],
      });
      final client = _FakeHttpClient(
        (request) async => _response(responseBody),
      );
      final repository = OverpassCourtRepository(httpClient: client);

      final court = await repository.watchCourt('osm:node-1').first;

      expect(court.id, 'osm:node-1');
      expect(court.name, 'City Court');
      expect(court.latitude, 48.85);
      expect(court.longitude, 2.35);
      expect(court.hoopCount, 4);
    });

    test('throws CourtNotFoundException for an unprefixed id without sending a '
        'request', () async {
      final client = _FakeHttpClient(
        (request) async => _response('{"elements": []}'),
      );
      final repository = OverpassCourtRepository(httpClient: client);

      await expectLater(
        repository.watchCourt('firestore-doc-1'),
        emitsError(isA<CourtNotFoundException>()),
      );
      expect(client.requestCount, 0);
    });
  });
}
