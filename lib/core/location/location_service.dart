abstract class LocationService {
  Future<UserPosition> currentPosition();
}

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

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();
}

class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();
}
