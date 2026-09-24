import 'package:cloud_firestore/cloud_firestore.dart';

enum StockStatus { normal, low, depleted }

/// A chemical "file". Its history lives in /transactions, never inside this document.
class ChemicalModel {
  const ChemicalModel({
    required this.id,
    required this.name,
    this.formula = '',
    required this.categoryId,
    required this.unit,
    this.currentStock = 0,
    this.minimumStock = 0,
    this.capacity,
    this.description,
    this.notes,
    this.casNumber,
    this.grade,
    this.location,
    this.hazardClass,
    this.tags = const [],
    this.lastTransactionId,
    this.lastEntryAt,
    this.lastEntryDelta,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String name;
  final String formula;
  final String categoryId;
  final String unit;
  final double currentStock;
  final double minimumStock;

  /// Optional bottle/cabinet capacity used for the gauge bar.
  final double? capacity;
  final String? description;
  final String? notes;
  final String? casNumber;
  final String? grade;
  final String? location;
  final String? hazardClass;
  final List<String> tags;

  /// Points at the transaction that produced [currentStock]. Security rules use it to prove
  /// every stock change is backed by an audit entry.
  final String? lastTransactionId;
  final DateTime? lastEntryAt;
  final double? lastEntryDelta;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  StockStatus get status {
    if (currentStock <= 0) return StockStatus.depleted;
    if (currentStock <= minimumStock) return StockStatus.low;
    return StockStatus.normal;
  }

  /// Spec: low stock when currentStock <= minimumStock (includes depleted).
  bool get isLow => status != StockStatus.normal;

  /// 0..1 fill for the gauge bar.
  double get gaugeRatio {
    final cap = capacity;
    final denom = (cap != null && cap > 0)
        ? cap
        : (minimumStock > 0 ? minimumStock * 4 : (currentStock > 0 ? currentStock : 1));
    return (currentStock / denom).clamp(0.0, 1.0).toDouble();
  }

  factory ChemicalModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    double num0(String k) => (d[k] as num?)?.toDouble() ?? 0;
    return ChemicalModel(
      id: doc.id,
      name: (d['name'] as String?) ?? 'Untitled',
      formula: (d['formula'] as String?) ?? '',
      categoryId: (d['categoryId'] as String?) ?? '',
      unit: (d['unit'] as String?) ?? 'L',
      currentStock: num0('currentStock'),
      minimumStock: num0('minimumStock'),
      capacity: (d['capacity'] as num?)?.toDouble(),
      description: d['description'] as String?,
      notes: d['notes'] as String?,
      casNumber: d['casNumber'] as String?,
      grade: d['grade'] as String?,
      location: d['location'] as String?,
      hazardClass: d['hazardClass'] as String?,
      tags: ((d['tags'] as List?) ?? const []).whereType<String>().toList(),
      lastTransactionId: d['lastTransactionId'] as String?,
      lastEntryAt: (d['lastEntryAt'] as Timestamp?)?.toDate(),
      lastEntryDelta: (d['lastEntryDelta'] as num?)?.toDouble(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] as String?,
    );
  }

  /// Full document for creation.
  Map<String, dynamic> toFirestore() => {
        'id': id,
        ..._metadata(),
        'unit': unit,
        'currentStock': currentStock,
        'lastTransactionId': lastTransactionId,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      };

  /// Fields safe to change without a stock transaction. Deliberately excludes the unit,
  /// the stock and the audit pointers.
  Map<String, dynamic> toMetadataUpdate() => _metadata();

  Map<String, dynamic> _metadata() => {
        'name': name,
        'nameLower': name.toLowerCase(),
        'formula': formula,
        'categoryId': categoryId,
        'minimumStock': minimumStock,
        'capacity': capacity,
        'description': description,
        'notes': notes,
        'casNumber': casNumber,
        'grade': grade,
        'location': location,
        'hazardClass': hazardClass,
        'tags': tags,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  ChemicalModel copyWith({
    String? id,
    String? name,
    String? formula,
    String? categoryId,
    String? unit,
    double? currentStock,
    double? minimumStock,
    double? capacity,
    String? description,
    String? notes,
    String? casNumber,
    String? grade,
    String? location,
    String? hazardClass,
    List<String>? tags,
    String? lastTransactionId,
    String? createdBy,
  }) =>
      ChemicalModel(
        id: id ?? this.id,
        name: name ?? this.name,
        formula: formula ?? this.formula,
        categoryId: categoryId ?? this.categoryId,
        unit: unit ?? this.unit,
        currentStock: currentStock ?? this.currentStock,
        minimumStock: minimumStock ?? this.minimumStock,
        capacity: capacity ?? this.capacity,
        description: description ?? this.description,
        notes: notes ?? this.notes,
        casNumber: casNumber ?? this.casNumber,
        grade: grade ?? this.grade,
        location: location ?? this.location,
        hazardClass: hazardClass ?? this.hazardClass,
        tags: tags ?? this.tags,
        lastTransactionId: lastTransactionId ?? this.lastTransactionId,
        lastEntryAt: lastEntryAt,
        lastEntryDelta: lastEntryDelta,
        createdAt: createdAt,
        updatedAt: updatedAt,
        createdBy: createdBy ?? this.createdBy,
      );
}
