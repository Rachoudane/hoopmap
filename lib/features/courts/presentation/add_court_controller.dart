import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../data/court_repository_provider.dart';
import '../domain/court.dart';

class AddCourtController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String name,
    required int hoopCount,
    required bool isOutdoor,
    required double latitude,
    required double longitude,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      _validate(
        name: name,
        hoopCount: hoopCount,
        latitude: latitude,
        longitude: longitude,
      );

      // Ensure a uid exists before the repository reads it as createdBy.
      await ref.read(anonymousSessionProvider.future);

      final court = Court(
        id: '',
        name: name,
        latitude: latitude,
        longitude: longitude,
        hoopCount: hoopCount,
        isOutdoor: isOutdoor,
        createdAt: DateTime.now(),
      );
      await ref.read(courtRepositoryProvider).addCourt(court);
    });
  }
}

void _validate({
  required String name,
  required int hoopCount,
  required double latitude,
  required double longitude,
}) {
  final trimmedName = name.trim();
  if (trimmedName.length < 3 || trimmedName.length > 60) {
    throw ArgumentError('Name must be between 3 and 60 characters.');
  }
  if (hoopCount < 1 || hoopCount > 20) {
    throw ArgumentError('Hoop count must be between 1 and 20.');
  }
  if (latitude < -90 || latitude > 90) {
    throw ArgumentError('Latitude must be between -90 and 90.');
  }
  if (longitude < -180 || longitude > 180) {
    throw ArgumentError('Longitude must be between -180 and 180.');
  }
}

final AsyncNotifierProvider<AddCourtController, void>
addCourtControllerProvider = AsyncNotifierProvider<AddCourtController, void>(
  AddCourtController.new,
);
