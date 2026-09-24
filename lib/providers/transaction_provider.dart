import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_providers.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import 'auth_provider.dart';

final transactionRepositoryProvider =
    Provider<TransactionRepository>((ref) => TransactionRepository(ref.watch(firestoreProvider)));

/// Full entry history for one chemical — every signed-in user sees the same ledger.
final chemicalEntriesProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, chemicalId) {
  if (ref.watch(uidProvider) == null) return Stream.value(const <TransactionModel>[]);
  return ref.watch(transactionRepositoryProvider).watchForChemical(chemicalId);
});

/// Recent activity across the whole archive.
final recentTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  if (ref.watch(uidProvider) == null) return Stream.value(const <TransactionModel>[]);
  return ref.watch(transactionRepositoryProvider).watchRecent();
});

/// Student name / ID hits from the ledger. Keyed by the debounced, lower-cased query.
final studentSearchProvider =
    FutureProvider.autoDispose.family<List<TransactionModel>, String>((ref, query) async {
  if (ref.watch(uidProvider) == null || query.length < 2) return const <TransactionModel>[];
  return ref.watch(transactionRepositoryProvider).searchStudents(query);
});

/// Report data for a date range. Records give us value equality for the key.
final rangeTransactionsProvider = FutureProvider.autoDispose
    .family<List<TransactionModel>, (DateTime, DateTime)>((ref, range) async {
  if (ref.watch(uidProvider) == null) return const <TransactionModel>[];
  return ref.watch(transactionRepositoryProvider).fetchRange(range.$1, range.$2);
});
