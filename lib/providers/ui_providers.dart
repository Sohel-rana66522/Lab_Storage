import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chemical_model.dart';

enum FolderSort {
  nameAsc('Name A-Z'),
  nameDesc('Name Z-A'),
  mostItems('Most chemicals'),
  lowFirst('Low stock first');

  const FolderSort(this.label);
  final String label;
}

enum ChemSort {
  balanceDesc('Balance: High → Low'),
  balanceAsc('Balance: Low → High'),
  nameAsc('Name A-Z'),
  recent('Recently updated');

  const ChemSort(this.label);
  final String label;

  int compare(ChemicalModel a, ChemicalModel b) {
    switch (this) {
      case ChemSort.balanceDesc:
        return b.currentStock.compareTo(a.currentStock);
      case ChemSort.balanceAsc:
        return a.currentStock.compareTo(b.currentStock);
      case ChemSort.nameAsc:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case ChemSort.recent:
        final ad = a.lastEntryAt ?? a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.lastEntryAt ?? b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
    }
  }
}

final folderGridProvider = StateProvider<bool>((ref) => true);
final folderSortProvider = StateProvider<FolderSort>((ref) => FolderSort.nameAsc);
final homeTagFilterProvider = StateProvider<String?>((ref) => null);

final chemGridProvider = StateProvider<bool>((ref) => false);
final chemSortProvider = StateProvider<ChemSort>((ref) => ChemSort.balanceDesc);
