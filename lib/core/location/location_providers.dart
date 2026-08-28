import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'geolocator_location_service.dart';
import 'location_service.dart';

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((ref) => GeolocatorLocationService());

/// The user's current position, resolved once and shared by everything that
/// needs it.
///
/// Both the map (to centre itself) and the nearby-courts query need the same
/// position; reading it through one provider means one fix, one permission
/// prompt, and one cached answer rather than two competing ones.
///
/// Auto-retry is disabled, like `nearbyCourtsProvider`: a denied permission
/// or a disabled GPS is not a transient failure, and retrying it in a loop
/// would re-prompt the user and drain the battery. Recovery is an explicit
/// refresh.
final FutureProvider<UserPosition> userPositionProvider =
    FutureProvider<UserPosition>(
      (ref) => ref.watch(locationServiceProvider).currentPosition(),
      retry: (retryCount, error) => null,
    );
