import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'geolocator_location_service.dart';
import 'location_service.dart';

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((ref) => GeolocatorLocationService());
