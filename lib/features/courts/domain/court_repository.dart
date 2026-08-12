import 'court.dart';

abstract class CourtRepository {
  Stream<List<Court>> watchCourts();
}
