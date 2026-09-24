import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_providers.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(firebaseAuthProvider)));

final authStateProvider =
    StreamProvider<User?>((ref) => ref.watch(authRepositoryProvider).authChanges());

/// The signed-in Firebase user, or null while signed out. There's no separate
/// profile document or role — Firebase Auth is the only source of truth, so
/// entering the app only ever depends on this.
final currentUserProvider = Provider<User?>((ref) => ref.watch(authStateProvider).valueOrNull);

final uidProvider = Provider<String?>((ref) => ref.watch(currentUserProvider)?.uid);
