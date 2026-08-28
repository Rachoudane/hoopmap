import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;

import 'location_service.dart';

/// [LocationService] backed by the real `geolocator` plugin.
///
/// Only the four primitives are implemented here — the "services, then
/// permission, then fix" sequencing lives in [LocationService.currentPosition]
/// so it stays identical across every implementation, real or fake.
class GeolocatorLocationService extends LocationService {
  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      _toStatus(await Geolocator.checkPermission());

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      _toStatus(await Geolocator.requestPermission());

  @override
  Future<UserPosition> readPosition() async =>
      _toUserPosition(await Geolocator.getCurrentPosition());

  @override
  Future<UserPosition?> lastKnownPosition() async {
    // Android can refuse to hand this back (and returns null) rather than
    // throwing; iOS returns the cached CLLocation when there is one.
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    return _toUserPosition(position);
  }

  static UserPosition _toUserPosition(Position position) {
    // geolocator reports an unknown accuracy as 0 (and Android occasionally
    // as a negative value); neither is a radius worth drawing, so both
    // become "no accuracy" rather than a circle of nothing.
    final accuracy = position.accuracy;
    return UserPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyInMeters: accuracy > 0 ? accuracy : null,
    );
  }

  // `unableToDetermine` is treated as a plain denial: the app has no
  // permission it can act on, but the user may still be able to grant one,
  // so it must not be reported as permanently denied.
  static LocationPermissionStatus _toStatus(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }
}
