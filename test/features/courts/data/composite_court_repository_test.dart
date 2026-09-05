import 'dart:async';

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

    test('waits for every source before answering at all', () async {
      // Firestore-shaped: instant and empty. OpenStreetMap-shaped: slower and
      // where the courts actually are. Answering on the first reply meant the
      // list rendered its "nobody has mapped this area" empty state and then
      // replaced it with forty courts.
      final fast = StreamController<List<Court>>();
      final slow = StreamController<List<Court>>();
      addTearDown(fast.close);
      addTearDown(slow.close);
      final repository = CompositeCourtRepository([
        _FakeCourtRepository(fast.stream),
        _FakeCourtRepository(slow.stream),
      ]);

      final emitted = <List<Court>>[];
      final subscription = repository
          .watchCourtsInBounds(bounds)
          .listen(emitted.add);
      addTearDown(subscription.cancel);

      fast.add(<Court>[]);
      await Future<void>.delayed(Duration.zero);
      expect(
        emitted,
        isEmpty,
        reason: 'an empty partial answer must never reach the UI',
      );

      slow.add([_court('a'), _court('b')]);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, hasLength(1));
      expect(emitted.single.map((c) => c.id).toSet(), {'a', 'b'});
    });

    test('lets live updates through once it has answered', () async {
      final first = StreamController<List<Court>>();
      final second = StreamController<List<Court>>();
      addTearDown(first.close);
      addTearDown(second.close);
      final repository = CompositeCourtRepository([
        _FakeCourtRepository(first.stream),
        _FakeCourtRepository(second.stream),
      ]);

      final emitted = <List<Court>>[];
      final subscription = repository
          .watchCourtsInBounds(bounds)
          .listen(emitted.add);
      addTearDown(subscription.cancel);

      first.add([_court('a')]);
      second.add(<Court>[]);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, hasLength(1));

      // Somebody adds a court while the list is open: that is a new value for
      // an answered search, and it must not be held back.
      second.add([_court('new')]);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, hasLength(2));
      expect(emitted.last.map((c) => c.id).toSet(), {'a', 'new'});
    });

    test('a failing source counts as having answered', () async {
      // Otherwise one dead source would hold every search open for ever.
      final working = StreamController<List<Court>>();
      final failing = StreamController<List<Court>>();
      addTearDown(working.close);
      final repository = CompositeCourtRepository([
        _FakeCourtRepository(working.stream),
        _FakeCourtRepository(failing.stream),
      ]);

      final emitted = <List<Court>>[];
      final subscription = repository
          .watchCourtsInBounds(bounds)
          .listen(emitted.add);
      addTearDown(subscription.cancel);

      working.add([_court('a')]);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty);

      failing.addError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(emitted, hasLength(1));
      expect(emitted.single.map((c) => c.id).toList(), ['a']);
      await failing.close();
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
