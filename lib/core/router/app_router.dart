import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/courts/presentation/pages/court_detail_page.dart';
import '../../features/courts/presentation/pages/courts_list_page.dart';
import '../presentation/pages/not_found_page.dart';
import 'routes.dart';

final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        name: Routes.homeName,
        builder: (context, state) => const CourtsListPage(),
        routes: [
          GoRoute(
            path: Routes.courtDetail,
            name: Routes.courtDetailName,
            builder: (context, state) {
              // Only matched when the courtIdParam segment is present in the
              // path, so it is always non-null here.
              final courtId = state.pathParameters[Routes.courtIdParam]!;
              return CourtDetailPage(courtId: courtId);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );
  ref.onDispose(router.dispose);
  return router;
});
