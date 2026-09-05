import 'analytics_event.dart';

/// Where an [AnalyticsEvent] goes.
///
/// An interface for the same reason `CourtRepository` and `CrashReporter`
/// are: what the app measures is a decision worth asserting in a test, and
/// no test here may need a real Firebase app.
abstract class AnalyticsService {
  /// Records [event].
  ///
  /// Call sites deliberately don't await this: reporting is backed by a
  /// network in the real implementation, and no screen, navigation or write
  /// may wait on a measurement of itself.
  Future<void> log(AnalyticsEvent event);

  /// Turns collection on or off, for this launch and every one after it.
  Future<void> setCollectionEnabled(bool enabled);
}

/// An [AnalyticsService] that measures nothing.
///
/// The default the app runs on until `main` wires the real one, which is what
/// keeps every widget test from needing a Firebase app to build a screen that
/// happens to log something.
class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> log(AnalyticsEvent event) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}
