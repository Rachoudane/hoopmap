import 'dart:async';

/// Where the user's device is, as far as the app is concerned.
class UserPosition {
  const UserPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPosition &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// The three permission states the app has to tell apart.
///
/// [denied] can still be recovered from by prompting again;
/// [deniedForever] cannot — the only way back is the system settings, which
/// is why the two are distinct values rather than a single "not granted".
enum LocationPermissionStatus { granted, denied, deniedForever }

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();
}

class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();
}

/// No fix arrived before the timeout and the device had no usable last known
/// position to fall back on — typically indoors, on a cold GPS start.
class LocationFixTimeoutException implements Exception {
  const LocationFixTimeoutException();
}

/// Access to the device's location, split into the primitives a caller may
/// need to drive separately.
///
/// Checking whether location services are on, reading the current permission,
/// asking for it, and actually taking a fix are distinct operations: a screen
/// that wants to show "location is off, turn it on" must be able to ask that
/// question without triggering a permission prompt, and a screen returning to
/// the foreground must be able to re-read the permission without taking a fix.
/// [currentPosition] composes them into the common "just give me a position"
/// flow.
abstract class LocationService {
  /// How long a fix is given before falling back to the last known position.
  ///
  /// A cold GPS start indoors can take far longer than this — the point isn't
  /// to abandon the fix quickly, it's to guarantee the UI is never left
  /// waiting on it indefinitely.
  static const Duration defaultFixTimeout = Duration(seconds: 10);

  /// Whether the device's location services (GPS) are switched on.
  /// Never prompts.
  Future<bool> isServiceEnabled();

  /// The permission currently granted to the app. Never prompts.
  Future<LocationPermissionStatus> checkPermission();

  /// Prompts for permission and resolves with the resulting status. On a
  /// permission already resolved to [LocationPermissionStatus.deniedForever],
  /// the system shows no prompt and the same status comes back.
  Future<LocationPermissionStatus> requestPermission();

  /// Takes a position fix. Assumes services are on and permission is granted:
  /// callers that haven't checked should use [currentPosition] instead.
  ///
  /// May take a long time, or never resolve at all — [currentPosition] is what
  /// bounds it.
  Future<UserPosition> readPosition();

  /// The last position the device recorded, if it still holds one. Resolves
  /// immediately and never takes a new fix, so it costs nothing to ask.
  Future<UserPosition?> lastKnownPosition();

  /// Services on → permission granted (prompting once if it hasn't been asked
  /// yet) → fix, bounded by [timeout].
  ///
  /// If the fix doesn't arrive in time, the device's last known position is
  /// returned instead: a slightly old position is far more useful than a
  /// spinner, and courts don't move.
  ///
  /// Throws [LocationServiceDisabledException] if location services are off,
  /// [LocationPermissionDeniedException] if permission is denied either way,
  /// and [LocationFixTimeoutException] if the fix times out with no last known
  /// position to fall back on.
  Future<UserPosition> currentPosition({
    Duration timeout = defaultFixTimeout,
  }) async {
    if (!await isServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }

    var status = await checkPermission();
    if (status == LocationPermissionStatus.denied) {
      status = await requestPermission();
    }
    if (status != LocationPermissionStatus.granted) {
      throw const LocationPermissionDeniedException();
    }

    try {
      return await readPosition().timeout(timeout);
    } on TimeoutException {
      final fallback = await lastKnownPosition();
      if (fallback != null) return fallback;
      throw const LocationFixTimeoutException();
    }
  }
}
