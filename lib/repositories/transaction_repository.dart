import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firestore_paths.dart';
import '../core/utils/errors.dart';
import '../core/utils/formatters.dart';
import '../core/utils/units.dart';
import '../models/chemical_model.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  TransactionRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Col.transactions);

  List<TransactionModel> _map(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(TransactionModel.fromFirestore).toList();

  /// Newest first. Ordered by commit time (createdAt) rather than the user-entered date so the
  /// stored running balances always chain correctly, even for back-dated entries.
  Stream<List<TransactionModel>> watchForChemical(String chemicalId, {int limit = 300}) => _col
      .where('chemicalId', isEqualTo: chemicalId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_map);

  Stream<List<TransactionModel>> watchRecent({int limit = 60}) =>
      _col.orderBy('createdAt', descending: true).limit(limit).snapshots().map(_map);

  /// Prefix search on student name and student ID, as entered on the Record
  /// Usage form — this is ledger data about who used a chemical, independent
  /// of any login account.
  Future<List<TransactionModel>> searchStudents(String lowerQuery, {int limit = 25}) async {
    final q = lowerQuery.trim().toLowerCase();
    if (q.length < 2) return const [];
    Future<QuerySnapshot<Map<String, dynamic>>> prefix(String field) => _col
        .where(field, isGreaterThanOrEqualTo: q)
        .where(field, isLessThan: '$q\uf8ff')
        .limit(limit)
        .get();
    final results = await Future.wait([prefix('studentNameLower'), prefix('studentIdLower')]);
    final byId = <String, TransactionModel>{};
    for (final snap in results) {
      for (final t in _map(snap)) {
        byId[t.id] = t;
      }
    }
    final list = byId.values.toList()..sort((a, b) => b.sortTime.compareTo(a.sortTime));
    return list;
  }

  /// All entries whose entry date falls inside [from, to] (inclusive days).
  Future<List<TransactionModel>> fetchRange(DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    final snap = await _col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();
    return _map(snap);
  }

  String? _clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

  /// The stock arithmetic, shared by [record] and by order approval so there is exactly ONE
  /// implementation of it:
  ///   1. checks the unit is compatible with the chemical's own unit,
  ///   2. converts the quantity into that unit,
  ///   3. computes `new stock = current stock ± quantity`,
  ///   4. refuses to go below zero.
  /// It is pure (no Firestore access), so it can be unit-tested directly.
  static StockPlan planEntry({
    required ChemicalModel chem,
    required TxType type,
    required double quantity,
    required String unit,
  }) {
    if (!quantity.isFinite || quantity <= 0) {
      throw AppException('Quantity must be greater than zero.');
    }
    if (!Units.isCompatible(unit, chem.unit)) {
      throw AppException(
          '${chem.name} is tracked in ${chem.unit}; $unit is not a compatible unit.');
    }
    final qty = Units.convert(quantity, unit, chem.unit);
    if (qty <= 0) throw AppException('That quantity is too small to record.');

    final signed = type == TxType.stockOut ? -qty : qty;
    final newStock = Units.round(chem.currentStock + signed);
    if (newStock < 0) {
      throw AppException('Not enough stock. Only ${Fmt.withUnit(chem.currentStock, chem.unit)} '
          'of ${chem.name} is available, but ${Fmt.withUnit(qty, chem.unit)} was requested.');
    }
    return StockPlan(quantity: qty, signed: Units.round(signed), newStock: newStock);
  }

  /// Writes one stock change inside an already-open Firestore transaction: the new stock on
  /// the chemical AND the immutable ledger entry, together. [entry] must have been built from
  /// the same [plan]. Reads must all have happened before this is called.
  static void stageEntry(
    Transaction tx, {
    required DocumentReference<Map<String, dynamic>> chemRef,
    required DocumentReference<Map<String, dynamic>> txRef,
    required TransactionModel entry,
    required StockPlan plan,
  }) {
    tx.update(chemRef, {
      'currentStock': plan.newStock,
      'lastTransactionId': txRef.id,
      'lastEntryAt': FieldValue.serverTimestamp(),
      'lastEntryDelta': plan.signed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    tx.set(txRef, entry.toFirestore());
  }

  /// Manual stock entry (Add Stock / Record Usage). Inside a Firestore transaction it:
  ///   1. re-reads the chemical (so concurrent edits cannot overwrite each other),
  ///   2. plans the change with [planEntry] (units, new balance, no negative stock),
  ///   3. writes the new stock AND the immutable ledger entry together.
  /// Firestore retries the closure automatically if another writer touched the document.
  Future<TransactionModel> record({
    required User actor,
    required String chemicalId,
    required TxType type,
    required double quantity,
    required String unit,
    required DateTime date,
    String? studentName,
    String? studentId,
    String? labBench,
    String? purpose,
    String? supplier,
    String? referenceNumber,
    String? remarks,
  }) async {
    if (!quantity.isFinite || quantity <= 0) {
      throw AppException('Quantity must be greater than zero.');
    }
    if (type == TxType.stockOut) {
      if (_clean(studentName) == null) throw AppException('Student name is required.');
      if (_clean(purpose) == null) throw AppException('Purpose / experiment is required.');
    }

    final chemRef = _db.collection(Col.chemicals).doc(chemicalId);
    final txRef = _col.doc();
    late TransactionModel result;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(chemRef);
      if (!snap.exists) throw AppException('This chemical no longer exists.');
      final chem = ChemicalModel.fromFirestore(snap);
      final plan = planEntry(chem: chem, type: type, quantity: quantity, unit: unit);

      result = TransactionModel(
        id: txRef.id,
        chemicalId: chem.id,
        chemicalName: chem.name,
        chemicalFormula: chem.formula,
        categoryId: chem.categoryId,
        type: type,
        quantity: plan.quantity,
        unit: chem.unit,
        enteredQuantity: quantity,
        enteredUnit: unit,
        balanceAfter: plan.newStock,
        studentId: type == TxType.stockOut ? _clean(studentId) : null,
        studentName: type == TxType.stockOut ? _clean(studentName) : null,
        labBench: _clean(labBench),
        purpose: _clean(purpose),
        supplier: type == TxType.stockIn ? _clean(supplier) : null,
        referenceNumber: type == TxType.stockIn ? _clean(referenceNumber) : null,
        remarks: _clean(remarks),
        date: date,
        createdBy: actor.uid,
        createdByName: Fmt.accountName(actor),
      );

      stageEntry(tx, chemRef: chemRef, txRef: txRef, entry: result, plan: plan);
    });

    return result;
  }
}

/// Result of [TransactionRepository.planEntry].
class StockPlan {
  const StockPlan({required this.quantity, required this.signed, required this.newStock});

  /// Quantity in the chemical's own unit (always positive).
  final double quantity;

  /// Change applied to stock: negative for usage, positive for stock received.
  final double signed;

  /// Stock after the change; never negative.
  final double newStock;
}
