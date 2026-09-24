import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_providers.dart';
import '../models/category_model.dart';
import '../repositories/category_repository.dart';
import 'auth_provider.dart';

final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => CategoryRepository(ref.watch(firestoreProvider)));

final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  if (ref.watch(uidProvider) == null) return Stream.value(const <CategoryModel>[]);
  return ref.watch(categoryRepositoryProvider).watchAll();
});
