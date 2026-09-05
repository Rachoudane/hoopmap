/// Where an error goes once the app has decided it is a bug rather than a
/// state the user can do something about.
///
/// An interface for the same reason `LocationService` and `CourtRepository`
/// are: what the app chooses to report — and, just as importantly, what it
/// chooses not to — is worth a test, and no test in this project may need a
/// real Firebase app to run.
abstract class CrashReporter {
  /// Records [error] against the current session.
  ///
  /// [fatal] tells apart a crash the app could not carry on past from one it
  /// caught and survived. Only the first counts against Crashlytics'
  /// crash-free-users rate, so mislabelling a caught error would make a
  /// healthy build look broken.
  ///
  /// [reason] is a short human sentence about where the error came from; it
  /// is what turns an entry in the dashboard into something searchable.
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  });

  /// Turns collection on or off, for this launch and every one after it.
  Future<void> setCollectionEnabled(bool enabled);
}
