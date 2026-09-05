import 'dart:async';

import '../domain/court.dart';
import '../domain/court_repository.dart';
import '../domain/geo_bounds.dart';

class CompositeCourtRepository implements CourtRepository {
  CompositeCourtRepository(this._repositories);

  final List<CourtRepository> _repositories;

  /// The courts in [bounds], from every source, merged.
  ///
  /// The first value is held back until every source has had its say — a
  /// value, an error, or the end of its stream. The sources answer at wildly
  /// different speeds: Firestore replies almost immediately, and almost
  /// always with nothing, because few courts are added by hand; OpenStreetMap
  /// takes a second or more and holds nearly all of them. Emitting each reply
  /// as it landed meant a search first answered "no courts here yet" and then
  /// corrected itself — and since that first answer reaches the UI, the list
  /// rendered its whole empty state, inviting the user to map an area that
  /// already had forty courts in it.
  ///
  /// After that first complete answer, later values flow straight through:
  /// those are live updates to a search already answered, not a search
  /// answering itself twice.
  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) {
    final sourceCount = _repositories.length;
    final latest = List<List<Court>?>.filled(sourceCount, null);
    final errors = List<Object?>.filled(sourceCount, null);
    // A source has answered once it has produced a value, failed, or ended.
    // Errors and endings count, or one dead source would hold the search open
    // for ever.
    final answered = List<bool>.filled(sourceCount, false);
    final subscriptions = <StreamSubscription<List<Court>>>[];
    var doneCount = 0;
    var hasEmittedData = false;
    var hasEmittedOnce = false;

    late final StreamController<List<Court>> controller;

    void emitIfReady() {
      // Nothing to show: every source so far has failed, which the close
      // handler below turns into an error rather than an empty result.
      if (!hasEmittedData) return;
      if (!hasEmittedOnce && answered.any((hasAnswered) => !hasAnswered)) {
        return;
      }
      hasEmittedOnce = true;
      controller.add(_merge(latest));
    }

    controller = StreamController<List<Court>>(
      onListen: () {
        for (var i = 0; i < sourceCount; i++) {
          subscriptions.add(
            _repositories[i]
                .watchCourtsInBounds(bounds)
                .listen(
                  (data) {
                    latest[i] = data;
                    answered[i] = true;
                    hasEmittedData = true;
                    emitIfReady();
                  },
                  onError: (Object error) {
                    errors[i] = error;
                    answered[i] = true;
                    emitIfReady();
                  },
                  onDone: () {
                    answered[i] = true;
                    doneCount++;
                    emitIfReady();
                    if (doneCount == sourceCount) {
                      if (!hasEmittedData) {
                        final firstError = errors.firstWhere(
                          (e) => e != null,
                          orElse: () => null,
                        );
                        if (firstError != null) {
                          controller.addError(firstError);
                        }
                      }
                      controller.close();
                    }
                  },
                ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  @override
  Stream<Court> watchCourt(String id) {
    final sourceCount = _repositories.length;
    final subscriptions = <StreamSubscription<Court>>[];
    var doneCount = 0;
    var hasEmittedData = false;

    late final StreamController<Court> controller;
    controller = StreamController<Court>(
      onListen: () {
        for (var i = 0; i < sourceCount; i++) {
          subscriptions.add(
            _repositories[i]
                .watchCourt(id)
                .listen(
                  (court) {
                    hasEmittedData = true;
                    controller.add(court);
                  },
                  onError: (Object error) {},
                  onDone: () {
                    doneCount++;
                    if (doneCount == sourceCount && !hasEmittedData) {
                      controller.addError(CourtNotFoundException(id));
                      controller.close();
                    }
                  },
                ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  @override
  Future<String> addCourt(Court court) async {
    for (final repository in _repositories) {
      try {
        return await repository.addCourt(court);
      } on UnsupportedError {
        continue;
      }
    }
    throw UnsupportedError('No repository supports adding a court.');
  }
}

List<Court> _merge(List<List<Court>?> sourceLists) {
  final merged = <String, Court>{};
  for (final courts in sourceLists) {
    if (courts == null) continue;
    for (final court in courts) {
      merged.putIfAbsent(court.id, () => court);
    }
  }
  return merged.values.toList();
}
