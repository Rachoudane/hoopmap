import 'court.dart';
import 'geo_bounds.dart';

class CourtNotFoundException implements Exception {
  CourtNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'CourtNotFoundException: no court found for id "$id".';
}

abstract class CourtRepository {
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds);

  Stream<Court> watchCourt(String id);

  Future<String> addCourt(Court court);
}
