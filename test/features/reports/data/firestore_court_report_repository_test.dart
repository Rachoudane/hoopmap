import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/reports/data/firestore_court_report_repository.dart';
import 'package:hoopmap/features/reports/domain/report_reason.dart';

void main() {
  group('FirestoreCourtReportRepository.reportCourt', () {
    test('writes a report document keyed by courtId and reporterUid, with all '
        'expected fields', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreCourtReportRepository(firestore: firestore);

      await repository.reportCourt(
        courtId: 'court-1',
        reason: ReportReason.spam,
        reporterUid: 'user-42',
        comment: 'Looks like an ad.',
      );

      final snapshot = await firestore
          .collection('reports')
          .doc('court-1_user-42')
          .get();
      expect(snapshot.exists, true);
      final data = snapshot.data()!;
      expect(data['courtId'], 'court-1');
      expect(data['reason'], 'spam');
      expect(data['comment'], 'Looks like an ad.');
      expect(data['reporterUid'], 'user-42');
      expect(data['status'], 'pending');
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('omits the comment field when none is given', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreCourtReportRepository(firestore: firestore);

      await repository.reportCourt(
        courtId: 'court-1',
        reason: ReportReason.doesNotExist,
        reporterUid: 'user-42',
      );

      final snapshot = await firestore
          .collection('reports')
          .doc('court-1_user-42')
          .get();
      expect(snapshot.data()!.containsKey('comment'), false);
    });
  });
}
