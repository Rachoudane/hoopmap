import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;

import 'location_service.dart';

class GeolocatorLocationService implements LocationService {
  @override
  Future<UserPosition> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException();
    }

    final position = await Geolocator.getCurrentPosition();
    return UserPosition(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
