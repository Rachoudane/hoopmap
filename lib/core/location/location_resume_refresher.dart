import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_providers.dart';
import 'location_service.dart';

/// Re-reads the location permission and the location services switch every
/// time the app comes back to the foreground, and throws away the cached
/// position fix when that answer no longer matches it.
///
/// Both settings live outside the app, and changing one sends the user out of
/// it: the "Open settings" button on a permission error, or the notification
/// shade for the GPS toggle. Without this, granting the permission the app
/// just asked for would leave the same error screen on display until the user
/// found the Retry button themselves — the app would be the last to know
/// about a change it prompted.
///
/// The refresh is deliberately two-way. A permission that appeared is a
/// reason to retry the fix; a permission that disappeared while the app was
/// backgrounded is a reason to stop showing a position that is no longer the
/// app's to show.
class LocationResumeRefresher extends ConsumerStatefulWidget {
  const LocationResumeRefresher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LocationResumeRefresher> createState() =>
      _LocationResumeRefresherState();
}

class _LocationResumeRefresherState
    extends ConsumerState<LocationResumeRefresher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Fire and forget: nothing awaits a lifecycle callback, and the only
      // outcome is an invalidation the widgets are already listening for.
      _refreshIfStale();
    }
  }

  Future<void> _refreshIfStale() async {
    // Both checks are silent — neither prompts — so this costs the user
    // nothing on the resumes where nothing changed, which is most of them.
    final service = ref.read(locationServiceProvider);
    final canLocate =
        await service.isServiceEnabled() &&
        await service.checkPermission() == LocationPermissionStatus.granted;

    if (!mounted) return;

    final position = ref.read(userPositionProvider);
    // A working fix stays untouched unless it has become unauthorized:
    // re-fetching a good position on every app switch would cost a GPS read
    // for an answer the app already has.
    final isStale = position.hasError ? canLocate : !canLocate;
    if (isStale) ref.invalidate(userPositionProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
