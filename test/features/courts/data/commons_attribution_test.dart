import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/data/commons_attribution.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:http/http.dart' as http;

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}

http.StreamedResponse _response(String body, {int statusCode = 200}) {
  return http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);
}

String _commonsResponse({
  required String artistHtml,
  String? licenseShortName,
}) {
  return jsonEncode({
    'query': {
      'pages': [
        {
          'imageinfo': [
            {
              'extmetadata': {
                'Artist': {'value': artistHtml},
                if (licenseShortName != null)
                  'LicenseShortName': {'value': licenseShortName},
              },
            },
          ],
        },
      ],
    },
  });
}

ProviderContainer _containerWith(http.Client client) {
  final container = ProviderContainer(
    overrides: [httpClientProvider.overrideWithValue(client)],
  );
  return container;
}

void main() {
  group('commonsAttributionProvider', () {
    test('resolves the author and license from extmetadata', () async {
      final client = _FakeHttpClient(
        (request) async => _response(
          _commonsResponse(
            artistHtml: '<a href="...">Jane Doe</a>',
            licenseShortName: 'CC BY-SA 4.0',
          ),
        ),
      );
      final container = _containerWith(client);
      addTearDown(container.dispose);

      final attribution = await container.read(
        commonsAttributionProvider('Court.jpg').future,
      );

      expect(attribution, isNotNull);
      expect(attribution!.author, 'Jane Doe');
      expect(attribution.licenseShortName, 'CC BY-SA 4.0');
    });

    test('resolves to null when the Artist field is blank', () async {
      final client = _FakeHttpClient(
        (request) async => _response(_commonsResponse(artistHtml: '')),
      );
      final container = _containerWith(client);
      addTearDown(container.dispose);

      final attribution = await container.read(
        commonsAttributionProvider('Court.jpg').future,
      );

      expect(attribution, isNull);
    });

    test('resolves to null when the page has no imageinfo', () async {
      final client = _FakeHttpClient(
        (request) async => _response(
          jsonEncode({
            'query': {
              'pages': [
                {'missing': true},
              ],
            },
          }),
        ),
      );
      final container = _containerWith(client);
      addTearDown(container.dispose);

      final attribution = await container.read(
        commonsAttributionProvider('Missing.jpg').future,
      );

      expect(attribution, isNull);
    });

    test('resolves to null on a non-200 response', () async {
      final client = _FakeHttpClient(
        (request) async => _response('rate limited', statusCode: 429),
      );
      final container = _containerWith(client);
      addTearDown(container.dispose);

      final attribution = await container.read(
        commonsAttributionProvider('Court.jpg').future,
      );

      expect(attribution, isNull);
    });

    test('resolves to null when the request throws', () async {
      final client = _FakeHttpClient(
        (request) async => throw Exception('no network'),
      );
      final container = _containerWith(client);
      addTearDown(container.dispose);

      final attribution = await container.read(
        commonsAttributionProvider('Court.jpg').future,
      );

      expect(attribution, isNull);
    });

    test('resolves to null on an unparseable response body', () async {
      final client = _FakeHttpClient((request) async => _response('not json'));
      final container = _containerWith(client);
      addTearDown(container.dispose);

      final attribution = await container.read(
        commonsAttributionProvider('Court.jpg').future,
      );

      expect(attribution, isNull);
    });
  });
}
