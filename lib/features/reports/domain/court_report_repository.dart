import 'report_reason.dart';

/// Thrown when the same [reporterUid] has already reported [courtId] —
/// see FirestoreCourtReportRepository for how this is detected without
/// ever reading another user's report.
class AlreadyReportedException implements Exception {
  AlreadyReportedException(this.courtId);

  final String courtId;

  @override
  String toString() =>
      'AlreadyReportedException: court "$courtId" was already reported by '
      'this user.';
}

abstract class CourtReportRepository {
  /// Files a report for [courtId]. Throws [AlreadyReportedException] if
  /// [reporterUid] has already reported this court.
  Future<void> reportCourt({
    required String courtId,
    required ReportReason reason,
    required String reporterUid,
    String? comment,
  });
}
