import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_service.dart';

/// How the rest of the app reports what happened.
///
/// Defaults to measuring nothing, and `main` overrides it with the Firebase
/// implementation. That way round on purpose: a screen that logs an event
/// must remain buildable in a test with no Firebase app, and there are far
/// more of those screens than there are composition roots.
final Provider<AnalyticsService> analyticsProvider = Provider<AnalyticsService>(
  (ref) => const NoOpAnalyticsService(),
);
