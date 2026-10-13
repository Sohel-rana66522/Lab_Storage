import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/services/firebase_providers.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../repositories/student_auth_repository.dart';

final studentAuthRepositoryProvider = Provider<StudentAuthRepository>(
  (ref) => StudentAuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)),
);

/// True while the login / sign-up form is running. The router ignores the new Firebase session
/// until it is false, so the portal never flashes open before the name check or the profile
/// write has finished (and failed attempts never get in).
final studentAuthBusyProvider = StateProvider<bool>((ref) => false);

/// A signed-in STUDENT (anonymous sessions and staff accounts do not count).
final isStudentSignedInProvider = Provider<bool>(
  (ref) => StudentAuthRepository.isStudentUser(ref.watch(currentUserProvider)),
);

/// The signed-in student's profile from `users/{uid}` (name, student ID, batch), or null.
final studentProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(isStudentSignedInProvider) ? ref.watch(uidProvider) : null;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection(Col.users)
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? UserModel.fromFirestore(s) : null);
});
