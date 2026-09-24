import 'package:cloud_firestore/cloud_firestore.dart';

enum TxType {
  stockIn('IN'),
  stockOut('OUT');

  const TxType(this.wire);
  final String wire;
  static TxType parse(String? v) => v == 'OUT' ? TxType.stockOut : TxType.stockIn;
}

/// One immutable line in a chemical's entry book.
///
/// [quantity]/[unit] are always in the chemical's own unit (so balances add up);
/// [enteredQuantity]/[enteredUnit] preserve what the staff member actually typed.
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.chemicalId,
    required this.chemicalName,
    this.chemicalFormula = '',
    required this.categoryId,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.enteredQuantity,
    required this.enteredUnit,
    required this.balanceAfter,
    this.studentId,
    this.studentName,
    this.studentUid,
    this.labBench,
    this.purpose,
    this.supplier,
    this.referenceNumber,
    this.remarks,
    this.isInitial = false,
    required this.date,
    this.createdAt,
    required this.createdBy,
    required this.createdByName,
  });

  final String id;
  final String chemicalId;
  final String chemicalName;
  final String chemicalFormula;
  final String categoryId;
  final TxType type;
  final double quantity;
  final String unit;
  final double enteredQuantity;
  final String enteredUnit;

  /// Running balance immediately after this entry (written atomically with the stock change).
  final double balanceAfter;
  final String? studentId;
  final String? studentName;
  final String? studentUid;
  final String? labBench;
  final String? purpose;
  final String? supplier;
  final String? referenceNumber;
  final String? remarks;
  final bool isInitial;
  final DateTime date;
  final DateTime? createdAt;
  final String createdBy;
  final String createdByName;

  bool get isIn => type == TxType.stockIn;
  DateTime get sortTime => createdAt ?? date;

  factory TransactionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    double n(String k) => (d[k] as num?)?.toDouble() ?? 0;
    final date = (d['date'] as Timestamp?)?.toDate() ??
        (d['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    return TransactionModel(
      id: doc.id,
      chemicalId: (d['chemicalId'] as String?) ?? '',
      chemicalName: (d['chemicalName'] as String?) ?? 'Unknown chemical',
      chemicalFormula: (d['chemicalFormula'] as String?) ?? '',
      categoryId: (d['categoryId'] as String?) ?? '',
      type: TxType.parse(d['type'] as String?),
      quantity: n('quantity'),
      unit: (d['unit'] as String?) ?? '',
      enteredQuantity: (d['enteredQuantity'] as num?)?.toDouble() ?? n('quantity'),
      enteredUnit: (d['enteredUnit'] as String?) ?? ((d['unit'] as String?) ?? ''),
      balanceAfter: n('balanceAfter'),
      studentId: d['studentId'] as String?,
      studentName: d['studentName'] as String?,
      studentUid: d['studentUid'] as String?,
      labBench: d['labBench'] as String?,
      purpose: d['purpose'] as String?,
      supplier: d['supplier'] as String?,
      referenceNumber: d['referenceNumber'] as String?,
      remarks: d['remarks'] as String?,
      isInitial: (d['isInitial'] as bool?) ?? false,
      date: date,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdBy: (d['createdBy'] as String?) ?? '',
      createdByName: (d['createdByName'] as String?) ?? 'Unknown',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'chemicalId': chemicalId,
        'chemicalName': chemicalName,
        'chemicalFormula': chemicalFormula,
        'categoryId': categoryId,
        'type': type.wire,
        'quantity': quantity,
        'unit': unit,
        'enteredQuantity': enteredQuantity,
        'enteredUnit': enteredUnit,
        'balanceAfter': balanceAfter,
        'studentId': studentId,
        'studentName': studentName,
        'studentUid': studentUid,
        // Lower-cased copies power prefix search on student name / ID.
        'studentIdLower': studentId?.toLowerCase(),
        'studentNameLower': studentName?.toLowerCase(),
        'labBench': labBench,
        'purpose': purpose,
        'supplier': supplier,
        'referenceNumber': referenceNumber,
        'remarks': remarks,
        'isInitial': isInitial,
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'createdByName': createdByName,
      };
}
