import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/auth/auth_providers.dart';
import 'package:hoopmap/features/reports/data/court_report_repository_provider.dart';
import 'package:hoopmap/features/reports/domain/court_report_repository.dart';
import 'package:hoopmap/features/reports/domain/report_reason.dart';
import 'package:hoopmap/features/reports/presentation/report_court_controller.dart';

class _FakeCourtReportRepository implements CourtReportRepository {
  final _reported = <String>{};
  int reportCourtCallCount = 0;
  String? lastCourtId;
  ReportReason? lastReason;
  String? lastComment;
  String? lastReporterUid;

  @override
  Future<void> reportCourt({
    required String courtId,
    required ReportReason reason,
    required String reporterUid,
    String? comment,
  }) async {
    reportCourtCallCount++;
    lastCourtId = courtId;
    lastReason = reason;
    lastComment = comment;
    lastReporterUid = reporterUid;

    final key = '${courtId}_$reporterUid';
    if (!_reported.add(key)) {
      throw AlreadyReportedException(courtId);
    }
  }
}

ProviderContainer _containerWith(_FakeCourtReportRepository repository) {
  return ProviderContainer(
    overrides: [
      courtReportRepositoryProvider.overrideWithValue(repository),
      anonymousSessionProvider.overrideWith((ref) async => 'test-uid'),
    ],
  );
}

void main() {
  group('ReportCourtController.submit', () {
    test(
      'a valid submission calls the repository once and settles as data',
      () async {
        final repository = _FakeCourtReportRepository();
        final container = _containerWith(repository);
        addTearDown(container.dispose);
        await container.read(reportCourtControllerProvider.future);

        await container
            .read(reportCourtControllerProvider.notifier)
            .submit(
              courtId: 'court-1',
              reason: ReportReason.inaccurate,
              comment: 'Wrong location',
            );

        expect(repository.reportCourtCallCount, 1);
        expect(repository.lastCourtId, 'court-1');
        expect(repository.lastReason, ReportReason.inaccurate);
        expect(repository.lastComment, 'Wrong location');
        expect(repository.lastReporterUid, 'test-uid');
        expect(
          container.read(reportCourtControllerProvider),
          isA<AsyncData<void>>(),
        );
      },
    );

    test('reporting the same court twice surfaces an AlreadyReportedException '
        'error state on the second attempt', () async {
      final repository = _FakeCourtReportRepository();
      final container = _containerWith(repository);
      addTearDown(container.dispose);

      await container
          .read(reportCourtControllerProvider.notifier)
          .submit(courtId: 'court-1', reason: ReportReason.spam);
      expect(
        container.read(reportCourtControllerProvider),
        isA<AsyncData<void>>(),
      );

      await container
          .read(reportCourtControllerProvider.notifier)
          .submit(courtId: 'court-1', reason: ReportReason.spam);

      expect(repository.reportCourtCallCount, 2);
      final state = container.read(reportCourtControllerProvider);
      expect(state.hasError, true);
      expect(state.error, isA<AlreadyReportedException>());
    });
  });
}
