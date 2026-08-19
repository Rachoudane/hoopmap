import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/court_repository_provider.dart';
import '../domain/court.dart';

final courtDetailProvider = StreamProvider.family<Court, String>(
  (ref, id) => ref.watch(courtRepositoryProvider).watchCourt(id),
  retry: (retryCount, error) => null,
);
