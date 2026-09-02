import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/settings/settings_providers.dart';
import 'core/theme/app_theme.dart';

class HoopmapApp extends ConsumerWidget {
  const HoopmapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Hoopmap',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      // Following the system is still the default; this only lets someone
      // who wants the other one say so.
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}
