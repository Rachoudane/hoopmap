import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/courts/presentation/pages/add_court_page.dart';
import '../../features/courts/presentation/pages/court_detail_page.dart';
import '../../features/courts/presentation/pages/courts_list_page.dart';
import '../../features/courts/presentation/pages/courts_map_page.dart';
import '../location/pages/location_rationale_page.dart';
import '../onboarding/onboarding_providers.dart';
import '../onboarding/pages/onboarding_page.dart';
import '../presentation/pages/app_shell.dart';
import '../presentation/pages/not_found_page.dart';
import '../terms/pages/terms_of_use_page.dart';
import 'routes.dart';

final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      // Android's <data android:scheme="hoopmap" android:host="courts"/>
      // intent-filter delivers hoopmap://courts/<id> with "courts" as the
      // URI *host*, not the path. go_router only ever matches against the
      // path, so left as-is this never reaches Routes.courtDetail — it
      // falls through to the error page. Rebuild the host into the path
      // before matching. Once redirected, the new location has no scheme
      // or host, so this doesn't loop.
      if (state.uri.scheme == 'hoopmap' && state.uri.host.isNotEmpty) {
        return '/${state.uri.host}${state.uri.path}';
      }

      final onboardingCompleted = ref.read(onboardingCompletedProvider);
      final goingToOnboarding = state.matchedLocation == Routes.onboarding;

      if (!onboardingCompleted && !goingToOnboarding) {
        return Routes.onboarding;
      }
      if (onboardingCompleted && goingToOnboarding) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        name: Routes.onboardingName,
        builder: (context, state) => const OnboardingPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                name: Routes.homeName,
                builder: (context, state) => const CourtsListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.map,
                name: Routes.mapName,
                builder: (context, state) => const CourtsMapPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.courtDetail,
        name: Routes.courtDetailName,
        builder: (context, state) {
          final courtId = state.pathParameters[Routes.courtIdParam]!;
          return CourtDetailPage(courtId: courtId);
        },
      ),
      GoRoute(
        path: Routes.addCourt,
        name: Routes.addCourtName,
        builder: (context, state) => const AddCourtPage(),
      ),
      GoRoute(
        path: Routes.locationRationale,
        name: Routes.locationRationaleName,
        builder: (context, state) => const LocationRationalePage(),
      ),
      GoRoute(
        path: Routes.terms,
        name: Routes.termsName,
        builder: (context, state) => const TermsOfUsePage(),
      ),
      GoRoute(
        path: Routes.termsAccept,
        name: Routes.termsAcceptName,
        builder: (context, state) =>
            const TermsOfUsePage(requireAcceptance: true),
      ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );
  ref.onDispose(router.dispose);
  return router;
});
