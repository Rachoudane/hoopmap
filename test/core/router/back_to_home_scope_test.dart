import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopmap/core/router/back_to_home_scope.dart';
import 'package:hoopmap/core/router/routes.dart';

const _homeKey = Key('home');
const _scopedKey = Key('scoped');

GoRouter _routerAt(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (context, state) =>
          const Scaffold(key: _homeKey, body: Text('Home')),
    ),
    GoRoute(
      path: '/scoped',
      builder: (context, state) => const Scaffold(
        key: _scopedKey,
        body: BackToHomeScope(child: Text('Scoped page')),
      ),
    ),
  ],
);

void main() {
  testWidgets(
    'when there is something to pop, the back gesture pops normally',
    (tester) async {
      final router = _routerAt(Routes.home);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/scoped');
      await tester.pumpAndSettle();

      expect(find.byKey(_scopedKey), findsOneWidget);

      final context = tester.element(find.byKey(_scopedKey));
      final didPop = await Navigator.maybePop(context);
      await tester.pumpAndSettle();

      expect(didPop, true);
      expect(find.byKey(_homeKey), findsOneWidget);
      expect(find.byKey(_scopedKey), findsNothing);
    },
  );

  testWidgets(
    'when there is nothing to pop (reached directly, e.g. a cold deep '
    'link), the back gesture goes home instead of throwing',
    (tester) async {
      final router = _routerAt('/scoped');
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byKey(_scopedKey), findsOneWidget);
      expect(find.byKey(_homeKey), findsNothing);

      final context = tester.element(find.byKey(_scopedKey));
      await Navigator.maybePop(context);
      await tester.pumpAndSettle();

      // What matters is where the user ends up: on a single-route stack
      // (context.canPop() is false, see BackToHomeScope), the scope's
      // onPopInvokedWithResult reacts by navigating home itself rather
      // than leaving the user stuck or crashing on GoRouter's "nothing to
      // pop" error.
      expect(find.byKey(_homeKey), findsOneWidget);
      expect(find.byKey(_scopedKey), findsNothing);
    },
  );
}
