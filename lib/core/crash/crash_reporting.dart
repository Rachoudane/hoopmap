import 'dart:async';
import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

/// Routes the errors Flutter would otherwise only print to the console into
/// [reporter].
///
/// Two hooks, because an error has two ways out of a Flutter app. A build,
/// layout or paint that throws — or any framework callback — reaches
/// [FlutterError.onError]; anything thrown from a future nobody is awaiting
/// reaches [PlatformDispatcher.onError] instead. Wiring only the first is the
/// common half-installation, and it is the half that misses the errors
/// hardest to reproduce by hand.
///
/// Both are recorded as fatal: neither stops the process, but both leave the
/// user in front of something the app never meant to show them, and a build
/// where that happens is not a healthy one.
///
/// Whatever was installed before is kept and called first, so the console
/// still says what it always said — the reporter is added to Flutter's error
/// handling, never substituted for it.
void installCrashReporting(CrashReporter reporter) {
  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousFlutterOnError?.call(details);
    unawaited(
      reporter.recordError(
        details.exception,
        details.stack,
        fatal: true,
        reason: details.context?.toDescription(),
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(reporter.recordError(error, stackTrace, fatal: true));
    // False, not true: the engine reads `true` as "handled, say no more" and
    // stops printing the error. The report has already been queued either
    // way, and swallowing the stderr line would cost every developer the one
    // trace they actually read.
    return false;
  };
}
