import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/auth/auth_providers.dart';
import 'core/onboarding/onboarding_providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final sharedPreferences = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sharedPreferences)],
  );
  // Fire-and-forget: the anonymous session is established in the background
  // so it doesn't delay the first frame.
  unawaited(container.read(anonymousSessionProvider.future));

  runApp(
    UncontrolledProviderScope(container: container, child: const HoopmapApp()),
  );
}
