import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_strings.dart';
import '../../location/location_resume_refresher.dart';

/// Bottom navigation between the two top-level destinations (List, Map).
/// Wraps a [StatefulShellRoute.indexedStack] branch so each tab keeps its
/// own navigation stack and scroll position when switching back and forth.
///
/// It is also where [LocationResumeRefresher] sits: both tabs depend on the
/// position fix, and the shell is the one widget that outlives switching
/// between them.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LocationResumeRefresher(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted_outlined),
            selectedIcon: Icon(Icons.format_list_bulleted),
            label: AppStrings.navList,
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: AppStrings.navMap,
          ),
        ],
      ),
    );
  }
}
