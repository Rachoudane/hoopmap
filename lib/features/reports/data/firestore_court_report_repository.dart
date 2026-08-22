import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/court_report_repository.dart';
import '../domain/report_reason.dart';

class FirestoreCourtReportRepository implements CourtReportRepository {
  FirestoreCourtReportRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<void> reportCourt({
    required String courtId,
    required ReportReason reason,
    required String reporterUid,
    String? comment,
  }) async {
    // Deterministic per (court, reporter) id, never read back by the
    // client (firestore.rules denies all client reads on this
    // collection). A first report is a Firestore "create" and is allowed;
    // a second attempt at the same id targets an existing document, which
    // Firestore evaluates as an "update" — denied by
    // `allow update: if false` — so the rules themselves reject a repeat
    // report without the app ever needing to read anyone's prior report.
    final reportId = '${courtId}_$reporterUid';
    try {
      await _firestore.collection('reports').doc(reportId).set({
        'courtId': courtId,
        'reason': reason.wireValue,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        'reporterUid': reporterUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw AlreadyReportedException(courtId);
      }
      rethrow;
    }
  }
}
