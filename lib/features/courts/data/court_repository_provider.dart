import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/firebase/firebase_providers.dart';
import '../domain/court_repository.dart';
import 'composite_court_repository.dart';
import 'firestore_court_repository.dart';
import 'overpass_court_repository.dart';

final Provider<http.Client> httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final Provider<CourtRepository> courtRepositoryProvider =
    Provider<CourtRepository>(
      (ref) => CompositeCourtRepository([
        OverpassCourtRepository(httpClient: ref.watch(httpClientProvider)),
        FirestoreCourtRepository(firestore: ref.watch(firestoreProvider)),
      ]),
    );
