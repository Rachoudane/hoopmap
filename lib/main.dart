import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/analytics/analytics_providers.dart';
import 'core/analytics/firebase_analytics_service.dart';
import 'core/auth/auth_providers.dart';
import 'core/crash/crash_reporting.dart';
import 'core/crash/crash_reporting_observer.dart';
import 'core/crash/firebase_crash_reporter.dart';
import 'core/onboarding/onboarding_providers.dart';
import 'features/courts/presentation/court_error_messages.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final analytics = FirebaseAnalyticsService();
  final crashReporter = FirebaseCrashReporter();
  // A crash from a laptop running `flutter run` lands in the same dashboard
  // as one from a phone in the wild, and says nothing about the build people
  // actually have. Off in debug, so what is left is signal.
  await crashReporter.setCollectionEnabled(!kDebugMode);
  installCrashReporting(crashReporter);
  // Same reasoning as crash reporting: a funnel measured on a developer's
  // laptop is a funnel nobody walks.
  await analytics.setCollectionEnabled(!kDebugMode);

  final sharedPreferences = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      // analyticsProvider measures nothing until this override, so a widget
      // test can build any screen without a Firebase app behind it.
      analyticsProvider.overrideWithValue(analytics),
    ],
    // The two hooks above only see errors that escape. Nearly every failure
    // in this app is caught by Riverpod first and drawn as a message, so the
    // observer is what makes crash reporting see the data layer at all.
    observers: [
      CrashReportingObserver(
        reporter: crashReporter,
        isExpected: isExpectedCourtError,
      ),
    ],
  );
  // Fire-and-forget: the anonymous session is established in the background
  // so it doesn't delay the first frame.
  unawaited(container.read(anonymousSessionProvider.future));

  runApp(
    UncontrolledProviderScope(container: container, child: const HoopmapApp()),
  );
}
