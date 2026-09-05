import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_providers.dart';
import '../../../core/analytics/app_events.dart';
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

    // Reported after the fact rather than around the write, so a submission
    // is counted as accepted only once Firestore has actually taken it.
    // Paired with the failures, this is the completion rate of the only form
    // in the app.
    final analytics = ref.read(analyticsProvider);
    unawaited(switch (state) {
      AsyncError(:final error) => analytics.log(
        AppEvents.addCourtFailed(_failureReason(error)),
      ),
      _ => analytics.log(
        AppEvents.addCourtSubmitted(hoopCount: hoopCount, isOutdoor: isOutdoor),
      ),
    });
  }
}

/// A form the user filled in wrong and a write that failed are two different
/// problems — one is a label to fix, the other an outage — and only this
/// tells them apart in the dashboard.
String _failureReason(Object error) =>
    error is ArgumentError ? 'invalid_input' : 'write_failed';

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
