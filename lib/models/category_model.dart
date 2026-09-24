import 'package:cloud_firestore/cloud_firestore.dart';

/// A folder in the file-manager metaphor.
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.location,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final String name;
  final String? description;

  /// Physical storage note, e.g. "Cabinet A-04 • Corrosives Locker".
  final String? location;
  final DateTime? createdAt;
  final String? createdBy;

  factory CategoryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return CategoryModel(
      id: doc.id,
      name: (d['name'] as String?) ?? 'Untitled',
      description: d['description'] as String?,
      location: d['location'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
        'nameLower': name.toLowerCase(),
        'description': description,
        'location': location,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'createdBy': createdBy,
      };

  CategoryModel copyWith({String? name, String? description, String? location, String? createdBy}) =>
      CategoryModel(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        location: location ?? this.location,
        createdAt: createdAt,
        createdBy: createdBy ?? this.createdBy,
      );
}
