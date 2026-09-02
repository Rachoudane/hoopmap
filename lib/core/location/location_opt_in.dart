import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding/onboarding_providers.dart' show sharedPreferencesProvider;

const String _locationOptInKey = 'location_opt_in';

/// Whether the user has asked the app to use their location.
///
/// Nothing about the app touches the device's location until this is true.
/// The system permission dialog is the most consequential thing Hoopmap ever
/// asks for, and it can only be asked well once: a user who has been shown
/// what the app is for says yes for a reason, while one who meets the dialog
/// on a screen they haven't read yet says no to be rid of it — and Android
/// remembers that second answer far better than the app can recover from it.
///
/// So the prompt is user-initiated, always: the last onboarding slide's call
/// to action, or the "See courts near me" button on a screen with no
/// position. Persisted, because "I already asked for this" should survive a
/// restart.
class LocationOptInNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_locationOptInKey) ??
        false;
  }

  /// Records that the user asked for their location, which is what lets the
  /// position fix — and with it the system prompt — run at all.
  Future<void> optIn() async {
    await ref.read(sharedPreferencesProvider).setBool(_locationOptInKey, true);
    state = true;
  }
}

final NotifierProvider<LocationOptInNotifier, bool> locationOptInProvider =
    NotifierProvider<LocationOptInNotifier, bool>(LocationOptInNotifier.new);
