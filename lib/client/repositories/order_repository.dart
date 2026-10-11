import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/units.dart';
import '../../models/category_model.dart';
import '../../models/chemical_model.dart';
import '../models/cart_line.dart';
import '../models/order_model.dart';

/// Creates client orders. This is the ONLY write the client portal performs, and it
/// writes to `orders/` alone: stock and the transaction ledger are never touched.
class OrderRepository {
  OrderRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Col.orders);

  // Keep these in step with firestore.rules.
  /// An approval writes ~2 documents per item inside one Firestore transaction whose rules
  /// are limited to 20 document accesses (see firestore.rules), so orders are capped.
  static const maxItems = 7;
  static const maxNameLength = 120;
  static const maxIdLength = 60;

  /// No 0/O or 1/I so IDs read clearly when spoken or copied by hand.
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// `LAB-` plus eight characters, e.g. `LAB-7K3MQ9XP`. Used as the document id.
  static String newOrderId([Random? random]) {
    final r = random ?? Random.secure();
    final tail = List.generate(8, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
    return 'LAB-$tail';
  }

  /// The orders placed by THIS portal session (matched on the anonymous uid), newest first.
  /// The security rules only let a session read its own orders, so this is also the only
  /// query that can succeed. Sorted here rather than with orderBy so no index is needed.
  Stream<List<OrderModel>> watchMine(String uid) =>
      _col.where('clientUid', isEqualTo: uid).snapshots().map((s) {
        final list = s.docs.map(OrderModel.fromFirestore).toList();
        list.sort((a, b) {
          // A just-submitted order has no server timestamp yet; treat it as newest.
          final at = a.createdAt ?? DateTime.now();
          final bt = b.createdAt ?? DateTime.now();
          return bt.compareTo(at);
        });
        return list;
      });

  /// Validates the request against the CURRENT stock on the server, then saves it as a
  /// pending order. Throws [AppException] with a message that is safe to show.
  Future<OrderModel> submit({
    required User actor,
    required String clientName,
    required String clientId,
    required String supervisorName,
    required List<CartLine> lines,
  }) async {
    final name = clientName.trim();
    final cid = clientId.trim();
    final sup = supervisorName.trim();

    if (name.isEmpty) throw AppException('Please enter the student/client name.');
    if (cid.isEmpty) throw AppException('Please enter the student/client ID.');
    if (sup.isEmpty) throw AppException('Please enter the supervisor name.');
    if (name.length > maxNameLength || sup.length > maxNameLength) {
      throw AppException('Names must be $maxNameLength characters or fewer.');
    }
    if (cid.length > maxIdLength) {
      throw AppException('The ID must be $maxIdLength characters or fewer.');
    }
    if (lines.isEmpty) throw AppException('Your cart is empty.');
    if (lines.length > maxItems) {
      throw AppException('An order can contain at most $maxItems chemicals.');
    }
    if (lines.map((l) => l.chemicalId).toSet().length != lines.length) {
      throw AppException('A chemical appears twice in your cart. Remove the duplicate.');
    }

    // Fresh stock straight from the server, never from a local cache. If the device is
    // offline this fails here, before anything is written.
    final snaps = await Future.wait([
      for (final l in lines)
        _db
            .collection(Col.chemicals)
            .doc(l.chemicalId)
            .get(const GetOptions(source: Source.server)),
    ]);

    final problems = <String>[];
    final chemicals = <ChemicalModel>[];
    for (var i = 0; i < lines.length; i++) {
      final snap = snaps[i];
      if (!snap.exists) {
        problems.add('A chemical in your cart is no longer available. Remove it and try again.');
        continue;
      }
      final chem = ChemicalModel.fromFirestore(snap);
      final issue = CartRules.validate(chem, lines[i]);
      if (issue != null) problems.add('${chem.name}: $issue');
      chemicals.add(chem);
    }
    if (problems.isNotEmpty) throw AppException(problems.toSet().join('\n'));

    // Folder names, copied into the order so it stays readable on its own.
    final categoryIds = {for (final c in chemicals) c.categoryId}..removeWhere((id) => id.isEmpty);
    final categoryNames = <String, String>{};
    await Future.wait([
      for (final id in categoryIds)
        _db.collection(Col.categories).doc(id).get().then((s) {
          if (s.exists) categoryNames[id] = CategoryModel.fromFirestore(s).name;
        }),
    ]);

    final items = [
      for (var i = 0; i < lines.length; i++)
        OrderItem(
          chemicalId: chemicals[i].id,
          chemicalName: chemicals[i].name,
          formula: chemicals[i].formula,
          requestedQuantity: Units.round(lines[i].quantity),
          unit: lines[i].unit,
          categoryId: chemicals[i].categoryId,
          categoryName: categoryNames[chemicals[i].categoryId] ?? '',
          baseQuantity: CartRules.toBase(chemicals[i], lines[i].quantity, lines[i].unit),
          baseUnit: chemicals[i].unit,
          availableAtRequest: chemicals[i].currentStock,
        ),
    ];

    final order = OrderModel(
      id: newOrderId(),
      clientName: name,
      clientId: cid,
      supervisorName: sup,
      items: items,
      clientUid: actor.uid,
    );

    await _col.doc(order.id).set(order.toFirestore());
    return order;
  }
}
