import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/utils/errors.dart';

/// Friendly messages for the client portal. Falls back to the laboratory app's own
/// [friendlyError] so wording stays consistent.
String clientErrorMessage(Object e) {
  // FirebaseAuthException is a FirebaseException, so test it first.
  if (e is FirebaseAuthException && e.code == 'operation-not-allowed') {
    return 'Student sign-in is not switched on yet. The laboratory needs to enable '
        'Email/Password sign-in in Firebase Authentication.';
  }
  if (e is FirebaseAuthException) {
    return e.code == 'network-request-failed'
        ? 'No internet connection. Check your network and try again.'
        : e.code == 'too-many-requests'
            ? 'Too many attempts. Please wait a moment and try again.'
            : 'Could not sign you in. Please refresh the page and try again.';
  }
  if (e is FirebaseException && e.code == 'permission-denied') {
    return 'The laboratory server did not accept this request. Please try again, '
        'or contact laboratory staff.';
  }
  return friendlyError(e);
}
