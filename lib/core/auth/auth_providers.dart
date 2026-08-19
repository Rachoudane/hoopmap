import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

// Signs the user in anonymously if they aren't already, and resolves with
// their uid. Reading this provider is how the rest of the app guarantees a
// session exists before performing an action that requires an uid.
final FutureProvider<String> anonymousSessionProvider = FutureProvider<String>((
  ref,
) async {
  final auth = ref.watch(firebaseAuthProvider);
  final currentUser = auth.currentUser;
  if (currentUser != null) {
    return currentUser.uid;
  }

  final credential = await auth.signInAnonymously();
  final user = credential.user;
  if (user == null) {
    throw StateError('Anonymous sign-in did not return a user.');
  }
  return user.uid;
});
