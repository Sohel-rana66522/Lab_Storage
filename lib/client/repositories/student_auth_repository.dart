import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/errors.dart';
import '../../models/user_model.dart';

/// Student sign-up / sign-in for the client portal.
///
/// Students identify themselves with their NAME and STUDENT ID only. Firebase Auth needs an
/// email + password, so both are derived from the Student ID (see [emailFor] / [passwordFor]).
/// The profile (name, ID, batch) lives in the `users` collection, keyed by the Firebase uid.
///
/// Keep [emailDomain] in step with `isStudent()` in firestore.rules.
class StudentAuthRepository {
  StudentAuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const emailDomain = 'students.labledger.app';
  static const maxNameLength = 120;
  static const maxIdLength = 40;
  static const maxBatchLength = 30;

  static final _idPattern = RegExp(r'^[A-Za-z0-9._-]+$');

  static String emailFor(String studentId) => '${studentId.trim().toLowerCase()}@$emailDomain';
  static String passwordFor(String studentId) => 'labledger-${studentId.trim().toLowerCase()}';

  /// True for a signed-in student account (never anonymous, never laboratory staff).
  static bool isStudentUser(User? u) =>
      u != null && !u.isAnonymous && (u.email ?? '').toLowerCase().endsWith('@$emailDomain');

  static String _collapse(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
  static String _normalizeName(String s) => _collapse(s).toLowerCase();

  // ---- validators (also used by the forms) ----

  static String? validateName(String? v) {
    final s = _collapse(v ?? '');
    if (s.isEmpty) return 'Enter your student name';
    if (s.length > maxNameLength) return 'At most $maxNameLength characters';
    return null;
  }

  static String? validateId(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Enter your student ID';
    if (s.length > maxIdLength) return 'At most $maxIdLength characters';
    if (!_idPattern.hasMatch(s)) return 'Use letters, numbers, - . _ only (no spaces)';
    return null;
  }

  static String? validateBatch(String? v) {
    final s = _collapse(v ?? '');
    if (s.isEmpty) return 'Enter your batch';
    if (s.length > maxBatchLength) return 'At most $maxBatchLength characters';
    return null;
  }

  static void _check(String? error) {
    if (error != null) throw AppException(error);
  }

  // ---- actions ----

  Future<void> signUp({
    required String name,
    required String studentId,
    required String batch,
  }) async {
    _check(validateName(name));
    _check(validateId(studentId));
    _check(validateBatch(batch));

    final cleanName = _collapse(name);
    final id = studentId.trim();

    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: emailFor(id),
        password: passwordFor(id),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw AppException('This Student ID is already registered. Please log in instead.');
      }
      rethrow;
    }

    final user = cred.user!;
    try {
      await _db.collection(Col.users).doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': cleanName,
        'role': UserRole.student.wire,
        'studentId': id,
        'batch': _collapse(batch),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // No profile means the account would be unusable; remove it so the student can retry.
      try {
        await user.delete();
      } catch (_) {
        await _auth.signOut();
      }
      rethrow;
    }
  }

  Future<void> signIn({required String name, required String studentId}) async {
    _check(validateName(name));
    _check(validateId(studentId));

    try {
      await _auth.signInWithEmailAndPassword(
        email: emailFor(studentId),
        password: passwordFor(studentId),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw AppException('No student account found for this Student ID. Please sign up first.');
      }
      rethrow;
    }

    try {
      final snap = await _db.collection(Col.users).doc(_auth.currentUser!.uid).get();
      final stored = (snap.data()?['displayName'] as String?) ?? '';
      if (!snap.exists || _normalizeName(stored) != _normalizeName(name)) {
        await _auth.signOut();
        throw AppException('Student name and Student ID do not match.');
      }
    } on AppException {
      rethrow;
    } catch (e) {
      await _auth.signOut();
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();
}
