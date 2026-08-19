import 'dart:async';

import '../domain/court.dart';
import '../domain/court_repository.dart';
import '../domain/geo_bounds.dart';

class CompositeCourtRepository implements CourtRepository {
  CompositeCourtRepository(this._repositories);

  final List<CourtRepository> _repositories;

  @override
  Stream<List<Court>> watchCourtsInBounds(GeoBounds bounds) {
    final sourceCount = _repositories.length;
    final latest = List<List<Court>?>.filled(sourceCount, null);
    final errors = List<Object?>.filled(sourceCount, null);
    final subscriptions = <StreamSubscription<List<Court>>>[];
    var doneCount = 0;
    var hasEmittedData = false;

    late final StreamController<List<Court>> controller;
    controller = StreamController<List<Court>>(
      onListen: () {
        for (var i = 0; i < sourceCount; i++) {
          subscriptions.add(
            _repositories[i]
                .watchCourtsInBounds(bounds)
                .listen(
                  (data) {
                    latest[i] = data;
                    hasEmittedData = true;
                    controller.add(_merge(latest));
                  },
                  onError: (Object error) {
                    errors[i] = error;
                  },
                  onDone: () {
                    doneCount++;
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
