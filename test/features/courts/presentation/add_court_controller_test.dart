import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/auth/auth_providers.dart';
import 'package:hoopmap/features/courts/data/court_repository_provider.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';
import 'package:hoopmap/features/courts/presentation/add_court_controller.dart';

class _FakeCourtRepository implements CourtRepository {
  _FakeCourtRepository({this.shouldThrow = false});

  final bool shouldThrow;
  int addCourtCallCount = 0;
  Court? lastAddedCourt;

  @override
  Future<String> addCourt(Court court) async {
    addCourtCallCount++;
    lastAddedCourt = court;
    if (shouldThrow) {
      throw Exception('boom');
    }
    return 'new-court-id';
  }

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) =>
      Stream.error(UnimplementedError());

  @override
  Stream<Court> watchCourt(String id) => Stream.error(UnimplementedError());
}

ProviderContainer _containerWith(_FakeCourtRepository repository) {
  final container = ProviderContainer(
    overrides: [
      courtRepositoryProvider.overrideWithValue(repository),
      anonymousSessionProvider.overrideWith((ref) async => 'test-uid'),
    ],
  );
  return container;
}

void main() {
  group('AddCourtController.submit', () {
    test('a valid submission calls addCourt once and moves through loading '
        'then data', () async {
      final repository = _FakeCourtRepository();
      final container = _containerWith(repository);
      addTearDown(container.dispose);

      // Let the notifier's initial build settle before observing
      // transitions, otherwise the loading state set by submit() is a no-op
      // (it's already loading from the not-yet-resolved initial build) and
      // never reaches the listener below.
      await container.read(addCourtControllerProvider.future);

      final states = <AsyncValue<void>>[];
      container.listen(addCourtControllerProvider, (previous, next) {
        states.add(next);
      });

      await container
          .read(addCourtControllerProvider.notifier)
          .submit(
            name: 'Test Court',
            hoopCount: 4,
            isOutdoor: true,
            latitude: 48.8566,
            longitude: 2.3522,
          );

      expect(repository.addCourtCallCount, 1);
      expect(repository.lastAddedCourt?.name, 'Test Court');
      expect(states.any((s) => s.isLoading), true);
      expect(
        container.read(addCourtControllerProvider),
        isA<AsyncData<void>>(),
      );
    });

    test('a repository error surfaces as an error state', () async {
      final repository = _FakeCourtRepository(shouldThrow: true);
      final container = _containerWith(repository);
      addTearDown(container.dispose);

      await container
          .read(addCourtControllerProvider.notifier)
          .submit(
            name: 'Test Court',
            hoopCount: 4,
            isOutdoor: true,
            latitude: 48.8566,
            longitude: 2.3522,
          );

      expect(repository.addCourtCallCount, 1);
      expect(container.read(addCourtControllerProvider).hasError, true);
    });
  });
}
