import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crash_reporter.dart';

/// Reports the provider failures nobody anticipated.
///
/// Without this, Crashlytics would see almost nothing in an app shaped like
/// this one: every failure in the data layer is caught by Riverpod, turned
/// into an `AsyncError`, and handed to a widget that draws a message. That is
/// the right thing for the user and a blind spot for the developer — the
/// error never becomes an uncaught one, so neither of the hooks
/// `installCrashReporting` sets up will ever see it.
///
/// [isExpected] is what keeps that from becoming noise. A refused location or
/// an Overpass instance that is down is a state the app already answers with
/// a screen, and reporting it would file a bug against every user who took a
/// train into a tunnel. What is worth a report is the leftover: an error the
/// app has no specific message for, which is precisely the definition of one
/// nobody thought about.
///
/// Recorded as non-fatal, because by construction the app survived it and
/// showed something.
final class CrashReportingObserver extends ProviderObserver {
  const CrashReportingObserver({
    required CrashReporter reporter,
    required bool Function(Object error) isExpected,
  }) : _reporter = reporter,
       _isExpected = isExpected;

  final CrashReporter _reporter;
  final bool Function(Object error) _isExpected;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (_isExpected(error)) return;

    unawaited(
      _reporter.recordError(
        error,
        stackTrace,
        reason: '${_label(context)} failed',
      ),
    );
  }

  /// A name for [provider] that is the same on every launch.
  ///
  /// `toString()` would be the obvious choice, but an unnamed provider falls
  /// back to its identity hash, which changes every run and would scatter one
  /// bug across as many Crashlytics issues as there are sessions.
  String _label(ProviderObserverContext context) =>
      context.provider.name ?? context.provider.runtimeType.toString();
}
