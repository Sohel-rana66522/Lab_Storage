import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication only — there's no separate Firestore profile
/// document and no roles. Whoever's email + password match a Firebase Auth
/// account gets straight into the app with full access.
class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// userChanges() (not authStateChanges()) so a display-name edit is picked
  /// up immediately too, not just sign-in/sign-out.
  Stream<User?> authChanges() => _auth.userChanges();

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password).then((_) {});

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await user.reload();
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();
}
