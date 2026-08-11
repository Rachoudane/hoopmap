import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/presentation/pages/not_found_page.dart';
import 'package:hoopmap/core/router/app_router.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';
import 'package:hoopmap/features/courts/presentation/pages/courts_list_page.dart';

Future<GoRouter> _pumpRouterApp(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final GoRouter router = container.read(goRouterProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  return router;
}

void main() {
  testWidgets('resolves /courts/:id to CourtDetailPage with the given id', (
    tester,
  ) async {
    final router = await _pumpRouterApp(tester);

    router.go('/courts/abc123');
    await tester.pumpAndSettle();

    final detailPage = tester.widget<CourtDetailPage>(
      find.byType(CourtDetailPage),
    );
    expect(detailPage.courtId, 'abc123');
  });

  testWidgets('resolves an unknown URL to NotFoundPage', (tester) async {
    final router = await _pumpRouterApp(tester);

    router.go('/this/does/not/exist');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundPage), findsOneWidget);
  });

  testWidgets('popping from court detail returns to CourtsListPage', (
    tester,
  ) async {
    final router = await _pumpRouterApp(tester);

    router.go('/courts/abc123');
    await tester.pumpAndSettle();
    expect(find.byType(CourtDetailPage), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(CourtsListPage), findsOneWidget);
  });
}
