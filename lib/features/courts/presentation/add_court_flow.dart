import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_providers.dart';
import '../../../core/analytics/app_events.dart';
import '../../../core/router/routes.dart';
import '../../../core/terms/terms_providers.dart';

/// The only way into the add-court form, from anywhere in the app.
///
/// The Terms of Use gate the first submission and there is no bypass: the
/// route isn't reachable from the `hoopmap://` deep link either (see
/// android/app/src/main/AndroidManifest.xml). Keeping the gate in one
/// function is what stops a second entry point — the empty state, the map —
/// from quietly becoming a way around it.
///
/// Someone who has already accepted goes straight to the form.
///
/// [entryPoint] is required for the same reason the gate is here: this is the
/// one place every door into the form passes through, so it is the only one
/// that can say which door — and an empty result leading to a contribution is
/// the app's most valuable path.
Future<void> openAddCourtFlow(
  BuildContext context,
  WidgetRef ref,
  AddCourtEntryPoint entryPoint,
) async {
  unawaited(
    ref.read(analyticsProvider).log(AppEvents.addCourtStarted(entryPoint)),
  );

  if (ref.read(termsAcceptedProvider)) {
    context.pushNamed(Routes.addCourtName);
    return;
  }

  final accepted = await context.pushNamed<bool>(Routes.termsAcceptName);
  if (accepted == true && context.mounted) {
    context.pushNamed(Routes.addCourtName);
  }
}
