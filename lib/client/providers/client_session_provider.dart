import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_providers.dart';
import '../../core/utils/errors.dart';

/// Gives every visitor a Firebase session without a login screen.
///
/// An existing session is reused (so a returning visitor keeps the same uid); otherwise
/// the visitor is signed in ANONYMOUSLY. Anonymous sessions can read the catalogue and
/// create orders, but the security rules never treat them as laboratory staff.
final clientSessionProvider = FutureProvider<User>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  // The first event is the restored session (or null), so we never sign in twice.
  var user = await auth.authStateChanges().first;
  user ??= (await auth.signInAnonymously()).user;
  if (user == null) throw AppException('Could not start a session. Please try again.');
  return user;
});
