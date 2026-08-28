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

/// Access to the device's location, split into the four independent steps a
/// caller may need to drive separately.
///
/// Checking whether location services are on, reading the current permission,
/// asking for it, and actually taking a fix are distinct operations: a screen
/// that wants to show "location is off, turn it on" must be able to ask that
/// question without triggering a permission prompt, and a screen returning to
/// the foreground must be able to re-read the permission without taking a fix.
/// [currentPosition] composes the four into the common "just give me a
/// position" flow.
abstract class LocationService {
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
  Future<UserPosition> readPosition();

  /// Services on → permission granted (prompting once if it hasn't been
  /// asked yet) → fix.
  ///
  /// Throws [LocationServiceDisabledException] if location services are off,
  /// and [LocationPermissionDeniedException] if permission is denied either
  /// way.
  Future<UserPosition> currentPosition() async {
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

    return readPosition();
  }
}
