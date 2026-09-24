import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/utils/errors.dart';
import '../models/category_model.dart';

class CategoryRepository {
  CategoryRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Col.categories);

  Stream<List<CategoryModel>> watchAll() => _col
      .orderBy('nameLower')
      .snapshots()
      .map((s) => s.docs.map(CategoryModel.fromFirestore).toList());

  String? _clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

  Future<void> _assertNameFree(String name, {String? exceptId}) async {
    final dup = await _col.where('nameLower', isEqualTo: name.trim().toLowerCase()).limit(2).get();
    if (dup.docs.any((d) => d.id != exceptId)) {
      throw AppException('A folder named "${name.trim()}" already exists.');
    }
  }

  Future<String> create({
    required String name,
    String? description,
    String? location,
    required String uid,
  }) async {
    if (name.trim().isEmpty) throw AppException('Folder name is required.');
    await _assertNameFree(name);
    final ref = _col.doc();
    try {
      print('Creating folder "$name" with id ${ref.id}');
      await ref.set(CategoryModel(
        id: ref.id,
        name: name.trim(),
        description: _clean(description),
        location: _clean(location),
        createdBy: uid,
      ).toFirestore());
      print('Created folder "$name" with id ${ref.id}');
    } catch (e) {
      throw AppException('Failed to create folder "$name": $e');
    }
   /* await ref.set(CategoryModel(
      id: ref.id,
      name: name.trim(),
      description: _clean(description),
      location: _clean(location),
      createdBy: uid,
    ).toFirestore());*/
    return ref.id;
  }

  Future<void> update(String id, {required String name, String? description, String? location}) async {
    if (name.trim().isEmpty) throw AppException('Folder name is required.');
    await _assertNameFree(name, exceptId: id);
    await _col.doc(id).update({
      'name': name.trim(),
      'nameLower': name.trim().toLowerCase(),
      'description': _clean(description),
      'location': _clean(location),
    });
  }

  /// A folder that still holds chemicals cannot be deleted; that would orphan their history.
  Future<void> delete(String id) async {
    final inside =
        await _db.collection(Col.chemicals).where('categoryId', isEqualTo: id).limit(1).get();
    if (inside.docs.isNotEmpty) {
      throw AppException('This folder still contains chemicals. Move or remove them first.');
    }
    await _col.doc(id).delete();
  }

  Future<void> seedDefaults(String uid) async {
    final batch = _db.batch();
    for (final name in defaultFolderNames) {
      final ref = _col.doc();
      batch.set(ref, CategoryModel(id: ref.id, name: name, createdBy: uid).toFirestore());
    }
    await batch.commit();
  }
}
