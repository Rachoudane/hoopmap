import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding/onboarding_providers.dart' show sharedPreferencesProvider;

const String _termsAcceptedKey = 'terms_of_use_accepted';

/// Whether the user has explicitly accepted the Terms of Use, persisted
/// across app launches the same way [onboardingCompletedProvider] persists
/// onboarding. Read by the "Add a court" flow to gate the first submission.
class TermsAcceptedNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_termsAcceptedKey) ??
        false;
  }

  Future<void> accept() async {
    await ref.read(sharedPreferencesProvider).setBool(_termsAcceptedKey, true);
    state = true;
  }
}

final NotifierProvider<TermsAcceptedNotifier, bool> termsAcceptedProvider =
    NotifierProvider<TermsAcceptedNotifier, bool>(TermsAcceptedNotifier.new);
