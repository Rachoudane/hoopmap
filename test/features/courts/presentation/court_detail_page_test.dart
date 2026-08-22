import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/auth/auth_providers.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/presentation/court_detail_provider.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';
import 'package:hoopmap/features/reports/data/court_report_repository_provider.dart';
import 'package:hoopmap/features/reports/domain/court_report_repository.dart';
import 'package:hoopmap/features/reports/domain/report_reason.dart';

const _courtId = 'court-a';

class _FakeCourtReportRepository implements CourtReportRepository {
  _FakeCourtReportRepository({this.alwaysThrowAlreadyReported = false});

  final bool alwaysThrowAlreadyReported;
  int reportCourtCallCount = 0;
  String? lastCourtId;
  ReportReason? lastReason;

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
    if (alwaysThrowAlreadyReported) {
      throw AlreadyReportedException(courtId);
    }
  }
}

Court _court({String id = _courtId}) => Court(
  id: id,
  name: 'Court Central',
  latitude: 48.8566,
  longitude: 2.3522,
  hoopCount: 4,
  isOutdoor: true,
  createdAt: DateTime(2026, 1, 1),
);

// CourtDetailPage reads GoRouter context (for its back-to-home fallback),
// so it is always pumped behind a minimal router rather than a bare
// MaterialApp.
GoRouter _detailRouter({String courtId = _courtId}) => GoRouter(
  initialLocation: Routes.courtDetail.replaceFirst(':id', courtId),
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Home'))),
    ),
    GoRoute(
      path: Routes.courtDetail,
      builder: (context, state) {
        final id = state.pathParameters[Routes.courtIdParam]!;
        return CourtDetailPage(courtId: id);
      },
    ),
  ],
);

void main() {
  testWidgets('displays the name, hoop count and indoor/outdoor information', (
    tester,
  ) async {
    final router = _detailRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courtDetailProvider(
            _courtId,
          ).overrideWith((ref) => Stream.value(_court())),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Court Central'), findsOneWidget);
    expect(find.text('4 hoops'), findsOneWidget);
    expect(find.text('Outdoor court'), findsOneWidget);
  });

  testWidgets('displays an error message instead of an empty screen', (
    tester,
  ) async {
    final router = _detailRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courtDetailProvider(
            _courtId,
          ).overrideWith((ref) => Stream.error(Exception('boom'))),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Court Central'), findsNothing);
  });

  testWidgets('a CourtNotFoundException shows a dedicated not-found screen', (
    tester,
  ) async {
    final router = _detailRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courtDetailProvider(_courtId).overrideWith(
            (ref) => Stream.error(CourtNotFoundException(_courtId)),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Court not found'), findsOneWidget);
    expect(find.text('Back to list'), findsOneWidget);
  });

  testWidgets('shows "Report this court" for a user-submitted court', (
    tester,
  ) async {
    final router = _detailRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courtDetailProvider(
            _courtId,
          ).overrideWith((ref) => Stream.value(_court())),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.reportThisCourt), findsOneWidget);
  });

  testWidgets(
    'never shows "Report this court" for an OpenStreetMap-sourced court',
    (tester) async {
      const osmId = 'osm:way-1';
      final router = _detailRouter(courtId: osmId);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courtDetailProvider(
              osmId,
            ).overrideWith((ref) => Stream.value(_court(id: osmId))),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.reportThisCourt), findsNothing);
    },
  );

  testWidgets(
    'submitting a report calls the repository and confirms with a snackbar',
    (tester) async {
      final router = _detailRouter();
      addTearDown(router.dispose);
      final reportRepository = _FakeCourtReportRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courtDetailProvider(
              _courtId,
            ).overrideWith((ref) => Stream.value(_court())),
            courtReportRepositoryProvider.overrideWithValue(reportRepository),
            anonymousSessionProvider.overrideWith((ref) async => 'test-uid'),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(OutlinedButton, AppStrings.reportThisCourt),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text(AppStrings.reportSubmit));
      await tester.pumpAndSettle();

      expect(reportRepository.reportCourtCallCount, 1);
      expect(reportRepository.lastCourtId, _courtId);
      expect(reportRepository.lastReason, ReportReason.inaccurate);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(AppStrings.reportSuccessSnackBar), findsOneWidget);
    },
  );

  testWidgets(
    'a repeat report shows an inline "already reported" message instead of '
    'closing the dialog',
    (tester) async {
      final router = _detailRouter();
      addTearDown(router.dispose);
      final reportRepository = _FakeCourtReportRepository(
        alwaysThrowAlreadyReported: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courtDetailProvider(
              _courtId,
            ).overrideWith((ref) => Stream.value(_court())),
            courtReportRepositoryProvider.overrideWithValue(reportRepository),
            anonymousSessionProvider.overrideWith((ref) async => 'test-uid'),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(OutlinedButton, AppStrings.reportThisCourt),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.reportSubmit));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(AppStrings.reportAlreadySubmitted), findsOneWidget);
    },
  );
}
