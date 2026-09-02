/// What the app calls itself, and which build this is.
///
/// Kept by hand rather than read from the platform at runtime: the only
/// screen that needs it is About, and a plugin (plus its platform channels,
/// on every platform) is a lot of machinery for one line of text. The
/// trade-off is that it can drift from `pubspec.yaml` — so a test reads the
/// pubspec and fails if it ever does.
abstract final class AppInfo {
  static const String name = 'Hoopmap';

  /// Mirrors the version in `pubspec.yaml` (the part before the `+`).
  static const String version = '1.0.1';

  /// Mirrors the build number in `pubspec.yaml` (the part after the `+`).
  static const String buildNumber = '2';

  static String get versionLabel => '$version ($buildNumber)';
}
