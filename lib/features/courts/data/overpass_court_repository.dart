import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/court.dart';
import '../domain/court_repository.dart';
import '../domain/geo_bounds.dart';
import 'overpass_mapper.dart';

final Uri _overpassEndpoint = Uri.parse(
  'https://overpass-api.de/api/interpreter',
);

// Overpass' public instance rejects overly large bounding boxes; this cap
// keeps requests well under that limit before they are ever sent.
const double _maxAreaInSquareDegrees = 25;

const Set<String> _validOsmTypes = {'node', 'way', 'relation'};

class OverpassException implements Exception {
  OverpassException(this.message);

  final String message;

  @override
  String toString() => 'OverpassException: $message';
}

/// Thrown specifically for HTTP 429 responses, so callers can show a
/// message distinct from a generic Overpass failure.
class OverpassRateLimitedException implements Exception {
  @override
  String toString() => 'OverpassRateLimitedException';
}

class AreaTooLargeException implements Exception {
  AreaTooLargeException(this.areaInSquareDegrees);

  final double areaInSquareDegrees;

  @override
  String toString() =>
      'AreaTooLargeException: requested area of $areaInSquareDegrees square '
      'degrees exceeds the limit of $_maxAreaInSquareDegrees square degrees.';
}

class OverpassCourtRepository implements CourtRepository {
  OverpassCourtRepository({required http.Client httpClient})
    : _httpClient = httpClient;

  final http.Client _httpClient;

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) async* {
    final area = bounds.areaInSquareDegrees;
    if (area > _maxAreaInSquareDegrees) {
      throw AreaTooLargeException(area);
    }

    yield await _fetchElements(_buildBoundsQuery(bounds));
  }

  @override
  Stream<Court> watchCourt(String id) async* {
    if (!id.startsWith('osm:')) {
      throw CourtNotFoundException(id);
    }

    final parsed = _parseOsmId(id);
    if (parsed == null) {
      throw CourtNotFoundException(id);
    }

    final courts = await _fetchElements(
      _buildElementQuery(parsed.$1, parsed.$2),
    );
    if (courts.isEmpty) {
      throw CourtNotFoundException(id);
    }

    yield courts.first;
  }

  @override
  Future<String> addCourt(Court court) {
    throw UnsupportedError('Courts cannot be added to OpenStreetMap.');
  }

  Future<List<Court>> _fetchElements(String query) async {
    final http.Response response;
    try {
      response = await _httpClient
          .post(
            _overpassEndpoint,
            headers: const {'User-Agent': 'Hoopmap/1.0'},
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw OverpassException('Overpass did not respond in time.');
    } catch (e) {
      // Covers connectivity failures (SocketException, no network, DNS
      // failure, ...): whatever the underlying platform exception is, it is
      // normalized to OverpassException so callers never see a raw
      // platform-specific type.
      throw OverpassException('Could not reach Overpass: $e');
    }

    if (response.statusCode == 429) {
      throw OverpassRateLimitedException();
    }
    if (response.statusCode != 200) {
      throw OverpassException(
        'Overpass returned status code ${response.statusCode}.',
      );
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawElements = decoded['elements'] as List<dynamic>;
      return rawElements
          .map((element) => element as Map<String, dynamic>)
          .map(courtFromOverpassElement)
          .whereType<Court>()
          .toList();
    } catch (e) {
      throw OverpassException('Could not read the Overpass response: $e');
    }
  }
}

(String, String)? _parseOsmId(String id) {
  final withoutPrefix = id.substring('osm:'.length);
  final separatorIndex = withoutPrefix.indexOf('-');
  if (separatorIndex == -1) return null;

  final type = withoutPrefix.substring(0, separatorIndex);
  final osmId = withoutPrefix.substring(separatorIndex + 1);
  if (!_validOsmTypes.contains(type) || int.tryParse(osmId) == null) {
    return null;
  }

  return (type, osmId);
}

String _buildBoundsQuery(GeoBounds bounds) {
  final bbox =
      '${bounds.minLat},${bounds.minLng},${bounds.maxLat},${bounds.maxLng}';
  return '[out:json][timeout:30];'
      '(node["leisure"="pitch"]["sport"~"basketball"]($bbox);'
      'way["leisure"="pitch"]["sport"~"basketball"]($bbox);'
      'relation["leisure"="pitch"]["sport"~"basketball"]($bbox);'
      ');'
      'out center tags;';
}

String _buildElementQuery(String type, String osmId) {
  return '[out:json][timeout:30];$type($osmId);out center tags;';
}
