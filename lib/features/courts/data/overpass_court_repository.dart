import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/court.dart';
import '../domain/court_repository.dart';
import '../domain/geo_bounds.dart';
import 'overpass_mapper.dart';

/// The public Overpass instances the app will talk to, in preference order.
///
/// The API is a volunteer service with no uptime guarantee: the main instance
/// goes down, gets slow, or rate-limits, and a single-endpoint client turns
/// any of that into "no courts anywhere". These are the community mirrors
/// that answer the same queries, so one of them being unwell costs the user
/// a few hundred milliseconds instead of the feature.
final List<Uri> defaultOverpassEndpoints = List.unmodifiable([
  Uri.parse('https://overpass-api.de/api/interpreter'),
  Uri.parse('https://overpass.kumi.systems/api/interpreter'),
  Uri.parse('https://overpass.private.coffee/api/interpreter'),
]);

/// How long a single instance is given to answer. Overpass' own usage policy
/// caps queries at 30 s, so waiting longer than that only holds the user on a
/// request the server has already given up on.
const Duration _defaultRequestTimeout = Duration(seconds: 30);

/// Delay before the first retry. Each further attempt waits twice as long, so
/// an instance that is merely busy isn't hammered on its way back up.
const Duration _defaultFirstRetryDelay = Duration(milliseconds: 400);

// Overpass' public instance rejects overly large bounding boxes; this cap
// keeps requests well under that limit before they are ever sent.
const double _maxAreaInSquareDegrees = 25;

const Set<String> _validOsmTypes = {'node', 'way', 'relation'};

class OverpassException implements Exception {
  OverpassException(this.message, {this.statusCode});

  final String message;

  /// The HTTP status behind the failure, when there was one. Null for a
  /// timeout, a connectivity failure, or a response that couldn't be read —
  /// which is also how a failure worth retrying elsewhere is told from a
  /// query the next instance would reject just as flatly.
  final int? statusCode;

  @override
  String toString() => 'OverpassException: $message';
}

/// Thrown specifically for HTTP 429 responses, so callers can show a
/// message distinct from a generic Overpass failure.
class OverpassRateLimitedException implements Exception {
  @override
  String toString() => 'OverpassRateLimitedException';
}

/// The device could not reach any Overpass instance at all — no response,
/// not even an error, from any of them.
///
/// Distinct from [OverpassException] because it is almost certainly not
/// about Overpass: three independent instances do not go dark at once nearly
/// as often as a phone loses its connection, and the two call for different
/// things from the user. Telling someone to check their connection while
/// they are online is as unhelpful as telling them to wait for a service
/// that is fine.
class NetworkUnavailableException implements Exception {
  const NetworkUnavailableException();

  @override
  String toString() => 'NetworkUnavailableException';
}

/// A request that never reached the server: no connection, DNS failure,
/// connection reset. Kept private because what the app acts on is whether
/// *every* instance was unreachable, which is what turns it into a
/// [NetworkUnavailableException].
class _UnreachableOverpassException extends OverpassException {
  _UnreachableOverpassException(super.message);
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
  OverpassCourtRepository({
    required http.Client httpClient,
    List<Uri>? endpoints,
    Duration firstRetryDelay = _defaultFirstRetryDelay,
    Duration requestTimeout = _defaultRequestTimeout,
    Future<void> Function(Duration duration)? wait,
  }) : _httpClient = httpClient,
       _endpoints = endpoints ?? defaultOverpassEndpoints,
       _firstRetryDelay = firstRetryDelay,
       _requestTimeout = requestTimeout,
       _wait = wait ?? _sleep,
       assert(
         endpoints == null || endpoints.isNotEmpty,
         'an Overpass repository with no endpoint could never answer',
       );

  final http.Client _httpClient;
  final List<Uri> _endpoints;
  final Duration _firstRetryDelay;
  final Duration _requestTimeout;
  final Future<void> Function(Duration duration) _wait;

  /// The instance that answered last, tried first next time.
  ///
  /// Without it, every single query would start over at an instance already
  /// known to be down and pay its timeout again.
  int _preferredEndpoint = 0;

  static Future<void> _sleep(Duration duration) =>
      Future<void>.delayed(duration);

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

  /// Runs [query] against the instances in turn until one answers.
  ///
  /// Only failures another instance could answer differently are passed on:
  /// a query the server rejected outright would be rejected just as flatly
  /// next door, and retrying it would spend someone else's quota to reach the
  /// same error. Whatever the last attempt failed with is what the caller
  /// sees, so a run that ends rate-limited still reads as rate-limited.
  Future<List<Court>> _fetchElements(String query) async {
    Object lastFailure = OverpassException('No Overpass instance was tried.');
    // Every instance out of reach says more about the device's connection
    // than about Overpass.
    var everyAttemptWasUnreachable = true;

    for (var attempt = 0; attempt < _endpoints.length; attempt++) {
      final index = (_preferredEndpoint + attempt) % _endpoints.length;
      try {
        final courts = await _fetchElementsFrom(_endpoints[index], query);
        _preferredEndpoint = index;
        return courts;
      } catch (failure) {
        if (!_isWorthRetryingElsewhere(failure)) rethrow;
        if (failure is! _UnreachableOverpassException) {
          everyAttemptWasUnreachable = false;
        }
        lastFailure = failure;
      }

      final isLastAttempt = attempt == _endpoints.length - 1;
      if (!isLastAttempt) {
        await _wait(_firstRetryDelay * (1 << attempt));
      }
    }

    if (everyAttemptWasUnreachable) throw const NetworkUnavailableException();
    throw lastFailure;
  }

  Future<List<Court>> _fetchElementsFrom(Uri endpoint, String query) async {
    final http.Response response;
    try {
      response = await _httpClient
          .post(
            endpoint,
            headers: const {'User-Agent': 'Hoopmap/1.0'},
            body: {'data': query},
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      // An instance that answers slowly is still an instance that answers:
      // a device with no connection fails long before this.
      throw OverpassException('Overpass did not respond in time.');
    } catch (e) {
      // Covers connectivity failures (SocketException, no network, DNS
      // failure, ...): whatever the underlying platform exception is, it is
      // normalized so callers never see a raw platform-specific type.
      throw _UnreachableOverpassException('Could not reach Overpass: $e');
    }

    if (response.statusCode == 429) {
      throw OverpassRateLimitedException();
    }
    if (response.statusCode != 200) {
      throw OverpassException(
        'Overpass returned status code ${response.statusCode}.',
        statusCode: response.statusCode,
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

/// Whether another instance is worth asking after [failure].
///
/// A rate limit is about this instance's load, and a timeout, an unreachable
/// host or an unreadable body say nothing about the query itself — all worth
/// asking elsewhere. A status the server chose to reject the request
/// with (4xx other than 429) is about the query, and every instance runs the
/// same one.
bool _isWorthRetryingElsewhere(Object failure) {
  if (failure is OverpassRateLimitedException) return true;
  if (failure is! OverpassException) return false;
  final status = failure.statusCode;
  return status == null || status >= 500;
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
