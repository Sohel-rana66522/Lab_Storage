import 'package:firebase_auth/firebase_auth.dart';

/// Business-rule error whose message is safe to show to the user as-is.
class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Turns any thrown object into a friendly message. Raw Firebase text is never shown.
String friendlyError(Object e) {
  if (e is AppException) return e.message;

  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your lab administrator.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
      case 'network-request-failed':
        return 'No internet connection. Your change was not saved.';
      case 'aborted':
      case 'already-exists':
        return 'Another user changed this chemical at the same time. Please review and try again.';
      case 'not-found':
        return 'That record could not be found. It may have been removed.';
      case 'failed-precondition':
        return 'The database is missing an index for this view. Deploy firestore.indexes.json and retry.';
      case 'deadline-exceeded':
        return 'The request timed out. Please try again.';
      default:
        return 'Something went wrong while talking to the server. Please try again.';
    }
  }

  return 'Something went wrong. Please try again.';
}
