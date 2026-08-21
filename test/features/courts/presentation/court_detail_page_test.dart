import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/presentation/court_detail_provider.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';

const _courtId = 'court-a';

Court _court() => Court(
  id: _courtId,
  name: 'Terrain Central',
  latitude: 48.8566,
  longitude: 2.3522,
  hoopCount: 4,
  isOutdoor: true,
  createdAt: DateTime(2026, 1, 1),
);

// CourtDetailPage reads GoRouter context (for its back-to-home fallback),
// so it is always pumped behind a minimal router rather than a bare
// MaterialApp.
GoRouter _detailRouter() => GoRouter(
  initialLocation: Routes.courtDetail.replaceFirst(':id', _courtId),
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Home'))),
    ),
    GoRoute(
      path: Routes.courtDetail,
      builder: (context, state) => const CourtDetailPage(courtId: _courtId),
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

    expect(find.text('Terrain Central'), findsOneWidget);
    expect(find.text('4 paniers'), findsOneWidget);
    expect(find.text('Terrain extérieur'), findsOneWidget);
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

    expect(
      find.text('Une erreur inattendue est survenue. Réessayez.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Terrain Central'), findsNothing);
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

    expect(find.text('Terrain introuvable'), findsOneWidget);
    expect(find.text('Retour à la liste'), findsOneWidget);
  });
}
