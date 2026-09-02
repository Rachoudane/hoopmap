import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/location/location_providers.dart';
import 'package:hoopmap/core/location/location_resume_refresher.dart';
import 'package:hoopmap/core/location/location_service.dart';

/// A location service whose answers can be changed mid-test, the way a user
/// changes them in the system settings while the app is in the background.
class _MutableLocationService extends LocationService {
  _MutableLocationService({
    this.serviceEnabled = true,
    this.permission = LocationPermissionStatus.granted,
  });

  bool serviceEnabled;
  LocationPermissionStatus permission;

  int readPositionCallCount = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => permission;

  @override
  Future<LocationPermissionStatus> requestPermission() async => permission;

  @override
  Future<UserPosition> readPosition() async {
    readPositionCallCount++;
    return const UserPosition(latitude: 48.8566, longitude: 2.3522);
  }

  @override
  Future<UserPosition?> lastKnownPosition() async => null;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

/// Pumps the refresher with the position provider already resolved, so the
/// tests act on a settled state rather than a fix still in flight.
Future<void> _pumpSettled(
  WidgetTester tester,
  _MutableLocationService service,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [locationServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        home: LocationResumeRefresher(child: _PositionReader()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Watches the position the way the real pages do, so the provider is alive
/// and the refresher has something to invalidate.
class _PositionReader extends ConsumerWidget {
  const _PositionReader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(userPositionProvider);
    return Text(switch (position) {
      AsyncData(:final value) => '${value.latitude}',
      AsyncError() => 'error',
      _ => 'loading',
    }, textDirection: TextDirection.ltr);
  }
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('retries the fix when a permission granted while the app was '
      'away makes it possible again', (tester) async {
    final service = _MutableLocationService(
      permission: LocationPermissionStatus.deniedForever,
    );
    await _pumpSettled(tester, service);

    expect(find.text('error'), findsOneWidget);
    expect(service.readPositionCallCount, 0);

    // What the user did in the settings the app just sent them to.
    service.permission = LocationPermissionStatus.granted;
    await _resume(tester);

    expect(find.text('48.8566'), findsOneWidget);
    expect(service.readPositionCallCount, 1);
  });

  testWidgets('retries the fix when location services come back on', (
    tester,
  ) async {
    final service = _MutableLocationService(serviceEnabled: false);
    await _pumpSettled(tester, service);

    expect(find.text('error'), findsOneWidget);

    service.serviceEnabled = true;
    await _resume(tester);

    expect(find.text('48.8566'), findsOneWidget);
  });

  testWidgets('leaves the error alone when nothing changed', (tester) async {
    final service = _MutableLocationService(
      permission: LocationPermissionStatus.deniedForever,
    );
    await _pumpSettled(tester, service);

    await _resume(tester);

    expect(find.text('error'), findsOneWidget);
    expect(service.readPositionCallCount, 0);
  });

  testWidgets('keeps a working position instead of re-fetching it on every '
      'app switch', (tester) async {
    final service = _MutableLocationService();
    await _pumpSettled(tester, service);

    expect(service.readPositionCallCount, 1);

    await _resume(tester);
    await _resume(tester);

    // A GPS read per return to the app would cost battery for an answer the
    // app already has.
    expect(service.readPositionCallCount, 1);
  });

  testWidgets('drops a position the app is no longer allowed to show', (
    tester,
  ) async {
    final service = _MutableLocationService();
    await _pumpSettled(tester, service);

    expect(find.text('48.8566'), findsOneWidget);

    // Revoked from the system settings while the app was in the background.
    service.permission = LocationPermissionStatus.deniedForever;
    await _resume(tester);

    expect(find.text('error'), findsOneWidget);
  });
}
