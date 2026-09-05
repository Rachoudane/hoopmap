import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics_event.dart';
import 'analytics_service.dart';

/// The one place in the app that touches `firebase_analytics`.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> log(AnalyticsEvent event) => _analytics.logEvent(
    name: event.name,
    parameters: event.parameters.isEmpty ? null : event.parameters,
  );

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);
}
