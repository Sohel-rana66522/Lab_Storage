import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_providers.dart';
import '../core/utils/formatters.dart';
import '../models/chemical_model.dart';
import '../repositories/chemical_repository.dart';
import 'auth_provider.dart';

final chemicalRepositoryProvider =
    Provider<ChemicalRepository>((ref) => ChemicalRepository(ref.watch(firestoreProvider)));

/// All chemicals, live. A lab holds hundreds, not millions, so one listener powers the home
/// counters, search, low-stock and folder views without extra reads.
final chemicalsProvider = StreamProvider<List<ChemicalModel>>((ref) {
  if (ref.watch(uidProvider) == null) return Stream.value(const <ChemicalModel>[]);
  return ref.watch(chemicalRepositoryProvider).watchAll();
});

final chemicalProvider = StreamProvider.family<ChemicalModel?, String>((ref, id) {
  if (ref.watch(uidProvider) == null) return Stream.value(null);
  return ref.watch(chemicalRepositoryProvider).watchOne(id);
});

/// Low-stock chemicals (currentStock <= minimumStock), most urgent first.
final lowStockProvider = Provider<AsyncValue<List<ChemicalModel>>>((ref) {
  return ref.watch(chemicalsProvider).whenData((all) {
    final low = all.where((c) => c.isLow).toList();
    low.sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index) * -1; // depleted first
      if (byStatus != 0) return byStatus;
      return a.gaugeRatio.compareTo(b.gaugeRatio);
    });
    return low;
  });
});

class FolderStats {
  const FolderStats({this.count = 0, this.low = 0, this.formulas = const []});
  final int count;
  final int low;
  final List<String> formulas;

  static Map<String, FolderStats> build(Iterable<ChemicalModel> chemicals) {
    final grouped = <String, List<ChemicalModel>>{};
    for (final c in chemicals) {
      (grouped[c.categoryId] ??= []).add(c);
    }
    return grouped.map((id, list) => MapEntry(
          id,
          FolderStats(
            count: list.length,
            low: list.where((c) => c.isLow).length,
            formulas: list
                .take(3)
                .map((c) => c.formula.isNotEmpty ? Fmt.formula(c.formula) : c.name)
                .toList(),
          ),
        ));
  }
}
