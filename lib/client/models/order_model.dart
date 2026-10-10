import 'package:cloud_firestore/cloud_firestore.dart';

/// Order lifecycle. The portal only ever creates [pending] orders; the laboratory
/// decides what happens next.
class OrderStatus {
  OrderStatus._();
  static const pending = 'Pending';
}

/// One requested chemical inside an order. It is a snapshot taken at submission time:
/// names and formulas are copied so the order still reads correctly if the chemical
/// is renamed later.
class OrderItem {
  const OrderItem({
    required this.chemicalId,
    required this.chemicalName,
    required this.formula,
    required this.requestedQuantity,
    required this.unit,
    required this.categoryId,
    required this.categoryName,
    required this.baseQuantity,
    required this.baseUnit,
    required this.availableAtRequest,
  });

  final String chemicalId;
  final String chemicalName;
  final String formula;

  /// Exactly what the client asked for, in the unit they chose (e.g. 500 mL).
  final double requestedQuantity;
  final String unit;

  final String categoryId;
  final String categoryName;

  /// The same amount in the unit the laboratory tracks this chemical in (e.g. 0.5 L),
  /// so staff can compare it directly with the ledger.
  final double baseQuantity;
  final String baseUnit;

  /// Stock the portal saw when the order was placed (in [baseUnit]). Informational.
  final double availableAtRequest;

  Map<String, dynamic> toMap() => {
        'chemicalId': chemicalId,
        'chemicalName': chemicalName,
        'formula': formula,
        'requestedQuantity': requestedQuantity,
        'unit': unit,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'baseQuantity': baseQuantity,
        'baseUnit': baseUnit,
        'availableAtRequest': availableAtRequest,
      };

  factory OrderItem.fromMap(Map<String, dynamic> d) => OrderItem(
        chemicalId: (d['chemicalId'] as String?) ?? '',
        chemicalName: (d['chemicalName'] as String?) ?? '',
        formula: (d['formula'] as String?) ?? '',
        requestedQuantity: (d['requestedQuantity'] as num?)?.toDouble() ?? 0,
        unit: (d['unit'] as String?) ?? '',
        categoryId: (d['categoryId'] as String?) ?? '',
        categoryName: (d['categoryName'] as String?) ?? '',
        baseQuantity: (d['baseQuantity'] as num?)?.toDouble() ?? 0,
        baseUnit: (d['baseUnit'] as String?) ?? '',
        availableAtRequest: (d['availableAtRequest'] as num?)?.toDouble() ?? 0,
      );
}

/// A chemical request placed from the client portal: `orders/{orderId}`.
class OrderModel {
  const OrderModel({
    required this.id,
    required this.clientName,
    required this.clientId,
    required this.supervisorName,
    required this.items,
    required this.clientUid,
    this.status = OrderStatus.pending,
    this.createdAt,
  });

  /// Also the document id, e.g. `LAB-7K3MQ9XP`.
  final String id;
  final String clientName;
  final String clientId;
  final String supervisorName;
  final List<OrderItem> items;

  /// Firebase Auth uid of the (anonymous) portal session that placed the order.
  final String clientUid;
  final String status;
  final DateTime? createdAt;

  /// The exact set of fields the security rules accept for a new order.
  Map<String, dynamic> toFirestore() => {
        'id': id,
        'clientName': clientName,
        'clientId': clientId,
        'supervisorName': supervisorName,
        'items': items.map((i) => i.toMap()).toList(),
        'itemCount': items.length,
        'status': status,
        'clientUid': clientUid,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return OrderModel(
      id: doc.id,
      clientName: (d['clientName'] as String?) ?? '',
      clientId: (d['clientId'] as String?) ?? '',
      supervisorName: (d['supervisorName'] as String?) ?? '',
      items: ((d['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => OrderItem.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      clientUid: (d['clientUid'] as String?) ?? '',
      status: (d['status'] as String?) ?? OrderStatus.pending,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
