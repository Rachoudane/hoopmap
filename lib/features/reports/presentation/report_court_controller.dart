import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_providers.dart';
import '../../../core/analytics/app_events.dart';
import '../../../core/auth/auth_providers.dart';
import '../data/court_report_repository_provider.dart';
import '../domain/report_reason.dart';

class ReportCourtController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String courtId,
    required ReportReason reason,
    String? comment,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Ensure a uid exists before the repository reads it as reporterUid.
      final reporterUid = await ref.read(anonymousSessionProvider.future);
      await ref
          .read(courtReportRepositoryProvider)
          .reportCourt(
            courtId: courtId,
            reason: reason,
            reporterUid: reporterUid,
            comment: comment,
          );
      // Inside the guard: a report that failed to write is not a report, and
      // counting it would overstate how much moderation the queue has.
      unawaited(
        ref.read(analyticsProvider).log(AppEvents.courtReported(reason.name)),
      );
    });
  }
}

final AsyncNotifierProvider<ReportCourtController, void>
reportCourtControllerProvider =
    AsyncNotifierProvider<ReportCourtController, void>(
      ReportCourtController.new,
    );
