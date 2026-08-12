import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/court_repository.dart';
import 'firestore_court_repository.dart';

final Provider<CourtRepository> courtRepositoryProvider =
    Provider<CourtRepository>(
      (ref) =>
          FirestoreCourtRepository(firestore: ref.watch(firestoreProvider)),
    );
