import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/auth/auth_providers.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/core/router/routes.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:hoopmap/features/courts/presentation/pages/add_court_page.dart';

class _FakeLocationService implements LocationService {
  @override
  Future<UserPosition> currentPosition() async =>
      const UserPosition(latitude: 48.8566, longitude: 2.3522);
}

class _FakeCourtRepository implements CourtRepository {
  int addCourtCallCount = 0;

  @override
  Future<String> addCourt(Court court) async {
    addCourtCallCount++;
    return 'new-court-id';
  }

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) =>
      Stream.error(UnimplementedError());

  @override
  Stream<Court> watchCourt(String id) => Stream.error(UnimplementedError());
}

// AddCourtPage calls context.pop() and shows a SnackBar on success, so it is
// pumped as a real sub-route of home rather than in isolation.
Future<_FakeCourtRepository> _pumpAddCourtPage(WidgetTester tester) async {
  final repository = _FakeCourtRepository();
  final router = GoRouter(
    initialLocation: '/${Routes.addCourt}',
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
        routes: [
          GoRoute(
            path: Routes.addCourt,
            builder: (context, state) => const AddCourtPage(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        courtRepositoryProvider.overrideWithValue(repository),
        anonymousSessionProvider.overrideWith((ref) async => 'test-uid'),
        locationServiceProvider.overrideWithValue(_FakeLocationService()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return repository;
}

void main() {
  testWidgets(
    'a name that is too short shows a validation error and does not call '
    'the repository',
    (tester) async {
      final repository = await _pumpAddCourtPage(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'ab');
      await tester.enterText(find.byType(TextFormField).at(1), '4');
      await tester.enterText(find.byType(TextFormField).at(2), '48.8566');
      await tester.enterText(find.byType(TextFormField).at(3), '2.3522');

      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(
        find.text('Le nom doit contenir entre 3 et 60 caractères'),
        findsOneWidget,
      );
      expect(repository.addCourtCallCount, 0);
    },
  );

  testWidgets('a valid form triggers the submission', (tester) async {
    final repository = await _pumpAddCourtPage(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Terrain Valide');
    await tester.enterText(find.byType(TextFormField).at(1), '4');
    await tester.enterText(find.byType(TextFormField).at(2), '48.8566');
    await tester.enterText(find.byType(TextFormField).at(3), '2.3522');

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(repository.addCourtCallCount, 1);
  });
}
