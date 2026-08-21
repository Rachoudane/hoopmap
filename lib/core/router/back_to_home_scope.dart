import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

/// Wraps a top-level page (court detail, add court) so its back button and
/// the system back gesture always lead somewhere useful: pop the current
/// stack when there is one (the common case, reached via a push from the
/// list or map), or go to the home route when there isn't — which happens
/// when the page is opened directly, e.g. a cold start on a deep link.
class BackToHomeScope extends StatelessWidget {
  const BackToHomeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(Routes.home);
      },
      child: child,
    );
  }
}
