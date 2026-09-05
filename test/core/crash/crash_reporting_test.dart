import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/crash/crash_reporter.dart';
import 'package:hoopmap/core/crash/crash_reporting.dart';
import 'package:hoopmap/core/crash/crash_reporting_observer.dart';
import 'package:hoopmap/core/l10n/app_strings.dart';
import 'package:hoopmap/core/location/location_service.dart';
import 'package:hoopmap/features/courts/data/overpass_court_repository.dart';
import 'package:hoopmap/features/courts/domain/court_repository.dart';
import 'package:hoopmap/features/courts/presentation/court_error_messages.dart';

class _RecordedError {
  const _RecordedError(this.error, this.stackTrace, this.fatal, this.reason);

  final Object error;
  final StackTrace? stackTrace;
  final bool fatal;
  final String? reason;
}

class _RecordingCrashReporter implements CrashReporter {
  final List<_RecordedError> recorded = <_RecordedError>[];
  final List<bool> collectionChanges = <bool>[];

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {
    recorded.add(_RecordedError(error, stackTrace, fatal, reason));
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionChanges.add(enabled);
  }
}

class _Boom implements Exception {
  const _Boom();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('installCrashReporting', () {
    late FlutterExceptionHandler? previousFlutterOnError;
    late bool Function(Object, StackTrace)? previousPlatformOnError;

    setUp(() {
      previousFlutterOnError = FlutterError.onError;
      previousPlatformOnError = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = previousFlutterOnError;
      PlatformDispatcher.instance.onError = previousPlatformOnError;
    });

    test('reports a framework error as fatal, with its context', () async {
      final reporter = _RecordingCrashReporter();
      // Standing in for the test framework's own handler, which would fail
      // the test if the chaining below reached it.
      final passedOn = <FlutterErrorDetails>[];
      FlutterError.onError = passedOn.add;

      installCrashReporting(reporter);

      final stackTrace = StackTrace.current;
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: const _Boom(),
          stack: stackTrace,
          context: ErrorDescription('while laying out the court list'),
        ),
      );

      expect(reporter.recorded, hasLength(1));
      expect(reporter.recorded.single.error, isA<_Boom>());
      expect(reporter.recorded.single.stackTrace, stackTrace);
      expect(reporter.recorded.single.fatal, isTrue);
      expect(
        reporter.recorded.single.reason,
        contains('while laying out the court list'),
      );
    });

    test('leaves the handler already installed in place', () {
      final reporter = _RecordingCrashReporter();
      final passedOn = <FlutterErrorDetails>[];
      FlutterError.onError = passedOn.add;

      installCrashReporting(reporter);
      FlutterError.onError!(FlutterErrorDetails(exception: const _Boom()));

      expect(passedOn, hasLength(1));
    });

    test(
      'reports an uncaught async error and lets the engine still print it',
      () {
        final reporter = _RecordingCrashReporter();
        installCrashReporting(reporter);

        final stackTrace = StackTrace.current;
        final handled = PlatformDispatcher.instance.onError!(
          const _Boom(),
          stackTrace,
        );

        expect(reporter.recorded, hasLength(1));
        expect(reporter.recorded.single.fatal, isTrue);
        expect(reporter.recorded.single.stackTrace, stackTrace);
        // True would tell the engine to stop printing the error, which is the
        // one line a developer reads.
        expect(handled, isFalse);
      },
    );
  });

  group('CrashReportingObserver', () {
    ProviderContainer containerWith(_RecordingCrashReporter reporter) {
      final container = ProviderContainer(
        observers: [
          CrashReportingObserver(
            reporter: reporter,
            isExpected: isExpectedCourtError,
          ),
        ],
        // Riverpod retries a failed provider on its own, and every attempt is
        // another failure: one report per test only stays true with retrying
        // switched off.
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);
      return container;
    }

    test('reports a provider failure the app has no message for', () {
      final reporter = _RecordingCrashReporter();
      final container = containerWith(reporter);
      final failing = FutureProvider<int>((ref) => throw const _Boom());

      expect(container.read(failing), isA<AsyncError<int>>());

      expect(reporter.recorded, hasLength(1));
      expect(reporter.recorded.single.error, isA<_Boom>());
      // Non-fatal: the app caught this one and drew a screen for it.
      expect(reporter.recorded.single.fatal, isFalse);
      expect(reporter.recorded.single.reason, contains('failed'));
    });

    test('stays silent on every failure the app already answers', () {
      final reporter = _RecordingCrashReporter();
      final container = containerWith(reporter);

      final expected = <Object>[
        const LocationNotRequestedException(),
        const LocationPermissionDeniedException(),
        const LocationPermissionPermanentlyDeniedException(),
        const LocationServiceDisabledException(),
        const LocationFixTimeoutException(),
        const NetworkUnavailableException(),
        OverpassRateLimitedException(),
        AreaTooLargeException(12.5),
        OverpassException('down'),
        CourtNotFoundException('osm:way-1'),
      ];

      for (final error in expected) {
        final failing = FutureProvider<int>((ref) => throw error);
        expect(container.read(failing), isA<AsyncError<int>>());
      }

      expect(reporter.recorded, isEmpty);
    });

    test('names the provider the same way on every launch', () {
      final reporter = _RecordingCrashReporter();
      final container = containerWith(reporter);
      final failing = FutureProvider<int>(
        (ref) => throw const _Boom(),
        name: 'nearbyCourtsProvider',
      );

      expect(container.read(failing), isA<AsyncError<int>>());

      expect(reporter.recorded.single.reason, 'nearbyCourtsProvider failed');
    });
  });

  group('isExpectedCourtError', () {
    test('agrees with the message the screen would show', () {
      const anticipated = LocationServiceDisabledException();
      expect(isExpectedCourtError(anticipated), isTrue);
      expect(courtErrorMessage(anticipated), isNot(AppStrings.errorUnexpected));

      const unanticipated = _Boom();
      expect(isExpectedCourtError(unanticipated), isFalse);
      expect(courtErrorMessage(unanticipated), AppStrings.errorUnexpected);
    });
  });
}
