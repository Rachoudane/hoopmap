import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics_event.dart';
import '../analytics/analytics_providers.dart';
import '../analytics/app_events.dart';
import '../router/routes.dart';
import 'location_opt_in.dart';

/// The single way the app asks for a location from inside the app: explain,
/// then let the system ask.
///
/// Every entry point goes through here — the offer on an empty list, the map
/// banner, the recenter button, the add-court form — so no button can reach
/// the system dialog without the screen that explains it, and none of them
/// has to remember that rule on its own.
///
/// Returns whether the user allowed. A user who already opted in is not
/// asked again: the explanation is for the first time, not for every use.
///
Future<bool> requestLocationOptIn(BuildContext context, WidgetRef ref) async {
  if (ref.read(locationOptInProvider)) return true;

  final analytics = ref.read(analyticsProvider);
  unawaited(analytics.log(AppEvents.locationRationaleShown()));

  final allowed = await context.pushNamed<bool>(Routes.locationRationaleName);
  if (allowed != true) {
    unawaited(analytics.log(AppEvents.locationDeclined()));
    return false;
  }

  // The screen underneath is being rebuilt as the explanation pops, and it
  // resumes the very providers this write invalidates. Letting the frame
  // finish first keeps the state change out of the middle of a build.
  await WidgetsBinding.instance.endOfFrame;
  await ref
      .read(locationOptInProvider.notifier)
      .optIn(LocationEntryPoint.inApp);
  return true;
}
