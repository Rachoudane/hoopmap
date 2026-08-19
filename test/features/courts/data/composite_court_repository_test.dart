import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/data/composite_court_repository.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/domain/geo_bounds.dart';

class _FakeCourtRepository implements CourtRepository {
  _FakeCourtRepository(this._stream) : _watchCourtStream = null;
  _FakeCourtRepository.forCourt(Stream<Court> watchCourtStream)
    : _stream = const Stream.empty(),
      _watchCourtStream = watchCourtStream;

  final Stream<List<Court>> _stream;
  final Stream<Court>? _watchCourtStream;

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) => _stream;

  @override
  Stream<Court> watchCourt(String id) =>
      _watchCourtStream ?? Stream.error(UnimplementedError());

  @override
  Future<String> addCourt(Court court) => throw UnimplementedError();
}

Court _court(String id) => Court(
  id: id,
  name: id,
  latitude: 0,
  longitude: 0,
  hoopCount: 1,
  isOutdoor: true,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  final bounds = GeoBounds.aroundPoint(0, 0, 1000);

  group('CompositeCourtRepository.watchCourtsInBounds', () {
    test('merges the results of every source', () async {
      final repository = CompositeCourtRepository([
        _FakeCourtRepository(Stream.value([_court('a')])),
        _FakeCourtRepository(Stream.value([_court('b')])),
      ]);

      final results = <List<Court>>[];
      await for (final courts in repository.watchCourtsInBounds(bounds)) {
        results.add(courts);
      }

      expect(results.last.map((c) => c.id).toSet(), {'a', 'b'});
    });

    test('deduplicates an id present in more than one source', () async {
      final repository = CompositeCourtRepository([
        _FakeCourtRepository(Stream.value([_court('a'), _court('shared')])),
        _FakeCourtRepository(Stream.value([_court('shared'), _court('b')])),
      ]);

      final results = <List<Court>>[];
      await for (final courts in repository.watchCourtsInBounds(bounds)) {
        results.add(courts);
      }

      final finalIds = results.last.map((c) => c.id).toList();
      expect(finalIds.toSet(), {'a', 'shared', 'b'});
      expect(finalIds.where((id) => id == 'shared'), hasLength(1));
    });

    test('still emits the other source result when one source fails', () async {
      final repository = CompositeCourtRepository([
        _FakeCourtRepository(Stream.value([_court('a')])),
        _FakeCourtRepository(Stream.error(StateError('boom'))),
      ]);

      final courts = await repository.watchCourtsInBounds(bounds).first;

      expect(courts.map((c) => c.id).toList(), ['a']);
    });

    test('propagates the first source error when every source fails', () async {
      final firstError = StateError('first failed');
      final repository = CompositeCourtRepository([
        _FakeCourtRepository(Stream.error(firstError)),
        _FakeCourtRepository(Stream.error(StateError('second failed'))),
      ]);

      await expectLater(
        repository.watchCourtsInBounds(bounds),
        emitsError(same(firstError)),
      );
    });
  });

  group('CompositeCourtRepository.watchCourt', () {
    test('finds the court when only the first source knows it', () async {
      final repository = CompositeCourtRepository([
        _FakeCourtRepository.forCourt(Stream.value(_court('a'))),
        _FakeCourtRepository.forCourt(
          Stream.error(CourtNotFoundException('a')),
        ),
      ]);

      final court = await repository.watchCourt('a').first;

      expect(court.id, 'a');
    });

    test('finds the court when only the second source knows it', () async {
      final repository = CompositeCourtRepository([
        _FakeCourtRepository.forCourt(
          Stream.error(CourtNotFoundException('a')),
        ),
        _FakeCourtRepository.forCourt(Stream.value(_court('a'))),
      ]);

      final court = await repository.watchCourt('a').first;

      expect(court.id, 'a');
    });

    test(
      'throws CourtNotFoundException when no source knows the court',
      () async {
        final repository = CompositeCourtRepository([
          _FakeCourtRepository.forCourt(
            Stream.error(CourtNotFoundException('a')),
          ),
          _FakeCourtRepository.forCourt(
            Stream.error(CourtNotFoundException('a')),
          ),
        ]);

        await expectLater(
          repository.watchCourt('a'),
          emitsError(isA<CourtNotFoundException>()),
        );
      },
    );
  });
}
