import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/court_report_repository.dart';
import 'firestore_court_report_repository.dart';

final Provider<CourtReportRepository> courtReportRepositoryProvider =
    Provider<CourtReportRepository>(
      (ref) => FirestoreCourtReportRepository(
        firestore: ref.watch(firestoreProvider),
      ),
    );
