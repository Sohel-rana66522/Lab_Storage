import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/firestore_paths.dart';
import '../core/utils/errors.dart';
import '../core/utils/formatters.dart';
import '../core/utils/units.dart';
import '../models/chemical_model.dart';
import '../models/transaction_model.dart';

class ChemicalRepository {
  ChemicalRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Col.chemicals);

  Stream<List<ChemicalModel>> watchAll() => _col
      .orderBy('nameLower')
      .snapshots()
      .map((s) => s.docs.map(ChemicalModel.fromFirestore).toList());

  Stream<ChemicalModel?> watchOne(String id) =>
      _col.doc(id).snapshots().map((s) => s.exists ? ChemicalModel.fromFirestore(s) : null);

  /// Creates the chemical file. If [initialStock] > 0 the opening balance is written as the
  /// first IN entry in the same atomic batch, so the ledger always adds up.
  Future<String> create({
    required ChemicalModel draft,
    required double initialStock,
    required DateTime date,
    required User actor,
  }) async {
    if (draft.name.trim().isEmpty) throw AppException('Chemical name is required.');
    if (initialStock < 0) throw AppException('Initial stock cannot be negative.');

    final ref = _col.doc();
    final batch = _db.batch();
    final stock = Units.round(initialStock);
    String? txId;

    if (stock > 0) {
      final txRef = _db.collection(Col.transactions).doc();
      txId = txRef.id;
      batch.set(
        txRef,
        TransactionModel(
          id: txId,
          chemicalId: ref.id,
          chemicalName: draft.name,
          chemicalFormula: draft.formula,
          categoryId: draft.categoryId,
          type: TxType.stockIn,
          quantity: stock,
          unit: draft.unit,
          enteredQuantity: stock,
          enteredUnit: draft.unit,
          balanceAfter: stock,
          remarks: 'Initial stock',
          isInitial: true,
          date: date,
          createdBy: actor.uid,
          createdByName: Fmt.accountName(actor),
        ).toFirestore(),
      );
    }

    final data = draft.copyWith(id: ref.id, createdBy: actor.uid).toFirestore();
    data['currentStock'] = stock;
    data['lastTransactionId'] = txId;
    if (stock > 0) {
      data['lastEntryAt'] = FieldValue.serverTimestamp();
      data['lastEntryDelta'] = stock;
    }
    batch.set(ref, data);
    await batch.commit();
    return ref.id;
  }

  /// Metadata only. Stock can only change through [TransactionRepository.record].
  Future<void> update(ChemicalModel c) => _col.doc(c.id).update(c.toMetadataUpdate());
}
