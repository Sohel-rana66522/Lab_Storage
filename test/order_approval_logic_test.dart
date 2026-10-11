import 'package:flutter_test/flutter_test.dart';
import 'package:lab_ledger/client/models/order_model.dart';
import 'package:lab_ledger/client/repositories/order_repository.dart';
import 'package:lab_ledger/core/utils/errors.dart';
import 'package:lab_ledger/models/chemical_model.dart';
import 'package:lab_ledger/models/transaction_model.dart';
import 'package:lab_ledger/repositories/order_admin_repository.dart';
import 'package:lab_ledger/repositories/transaction_repository.dart';

// Pure-logic tests for order approval. They do not touch Firestore: the atomic transaction
// itself and the security rules are covered by test_rules/ (Firebase Emulator).

ChemicalModel chem({
  String id = 'c1',
  String name = 'Hydrochloric Acid',
  String unit = 'L',
  double stock = 2.5,
}) =>
    ChemicalModel(id: id, name: name, formula: 'HCl', categoryId: 'cat', unit: unit, currentStock: stock);

OrderItem item({
  String id = 'c1',
  String name = 'Hydrochloric Acid',
  double qty = 500,
  String unit = 'mL',
}) =>
    OrderItem(
      chemicalId: id,
      chemicalName: name,
      formula: 'HCl',
      requestedQuantity: qty,
      unit: unit,
      categoryId: 'cat',
      categoryName: 'Acids',
      baseQuantity: 0,
      baseUnit: 'L',
      availableAtRequest: 0,
    );

OrderModel order(List<OrderItem> items, {String status = OrderStatus.pending}) => OrderModel(
      id: 'LAB-ABCD2345',
      clientName: 'Rahim Ahmed',
      clientId: '2024001',
      supervisorName: 'Dr. Karim',
      items: items,
      clientUid: 'anon1',
      status: status,
    );

void main() {
  group('TransactionRepository.planEntry (shared stock rule)', () {
    test('issuing deducts: new stock = current stock - issued quantity', () {
      final plan = TransactionRepository.planEntry(
          chem: chem(stock: 2.5), type: TxType.stockOut, quantity: 500, unit: 'mL');
      expect(plan.quantity, 0.5);
      expect(plan.signed, -0.5);
      expect(plan.newStock, 2.0);
    });

    test('stock received adds', () {
      final plan = TransactionRepository.planEntry(
          chem: chem(stock: 1), type: TxType.stockIn, quantity: 250, unit: 'mL');
      expect(plan.newStock, 1.25);
    });

    test('issuing exactly the whole stock is allowed and leaves zero', () {
      final plan = TransactionRepository.planEntry(
          chem: chem(stock: 0.5), type: TxType.stockOut, quantity: 500, unit: 'mL');
      expect(plan.newStock, 0);
    });

    test('stock can never go negative', () {
      expect(
        () => TransactionRepository.planEntry(
            chem: chem(stock: 0.5), type: TxType.stockOut, quantity: 501, unit: 'mL'),
        throwsA(isA<AppException>()
            .having((e) => e.message, 'message', contains('Not enough stock'))),
      );
    });

    test('rejects an incompatible unit', () {
      expect(
        () => TransactionRepository.planEntry(
            chem: chem(unit: 'L'), type: TxType.stockOut, quantity: 5, unit: 'g'),
        throwsA(isA<AppException>()),
      );
    });

    test('rejects zero, negative and non-finite quantities', () {
      for (final q in [0.0, -3.0, double.nan, double.infinity]) {
        expect(
          () => TransactionRepository.planEntry(
              chem: chem(), type: TxType.stockOut, quantity: q, unit: 'L'),
          throwsA(isA<AppException>()),
          reason: 'quantity $q',
        );
      }
    });

    test('mass units convert (200 g from 1 kg leaves 0.8 kg)', () {
      final plan = TransactionRepository.planEntry(
          chem: chem(unit: 'kg', stock: 1), type: TxType.stockOut, quantity: 200, unit: 'g');
      expect(plan.newStock, 0.8);
    });
  });

  group('Order approval preconditions', () {
    test('ledger ids are deterministic, ordered and match the rules pattern', () {
      expect(OrderAdminRepository.ledgerIdFor('LAB-ABCD2345', 0), 'LAB-ABCD2345-1');
      expect(OrderAdminRepository.ledgerIdFor('LAB-ABCD2345', 2), 'LAB-ABCD2345-3');
      // firestore.rules: transactionId.matches(orderId + '-[0-9]+')
      final rule = RegExp(r'^LAB-ABCD2345-[0-9]+$');
      expect(rule.hasMatch(OrderAdminRepository.ledgerIdFor('LAB-ABCD2345', 6)), isTrue);
    });

    test('a well-formed multi-chemical order passes the shape check', () {
      final o = order([
        item(id: 'a', name: 'Hydrochloric Acid', qty: 500, unit: 'mL'),
        item(id: 'b', name: 'Sodium Hydroxide', qty: 200, unit: 'g'),
        item(id: 'c', name: 'Sodium Chloride', qty: 100, unit: 'g'),
      ]);
      expect(OrderAdminRepository.checkShape(o), isNull);
    });

    test('an empty order is refused', () {
      expect(OrderAdminRepository.checkShape(order([])), isNotNull);
    });

    test('the same chemical twice is refused (it would double-write one chemical)', () {
      final o = order([item(id: 'a'), item(id: 'a')]);
      expect(OrderAdminRepository.checkShape(o), contains('twice'));
    });

    test('invalid quantities and missing units are refused', () {
      expect(OrderAdminRepository.checkShape(order([item(qty: 0)])), isNotNull);
      expect(OrderAdminRepository.checkShape(order([item(qty: -1)])), isNotNull);
      expect(OrderAdminRepository.checkShape(order([item(qty: double.nan)])), isNotNull);
      expect(OrderAdminRepository.checkShape(order([item(unit: '')])), isNotNull);
    });

    test('more items than the rules can verify are refused', () {
      final many = [for (var i = 0; i < OrderAdminRepository.maxItemsPerApproval + 1; i++) item(id: 'c$i')];
      expect(OrderAdminRepository.checkShape(order(many)), contains('at most'));
    });

    test('the client cap and the approval cap agree', () {
      expect(OrderRepository.maxItems, OrderAdminRepository.maxItemsPerApproval);
    });
  });

  group('OrderModel status helpers', () {
    test('status flags', () {
      expect(order([item()]).isPending, isTrue);
      expect(order([item()], status: OrderStatus.approved).isApproved, isTrue);
      expect(order([item()], status: OrderStatus.rejected).isRejected, isTrue);
    });

    test('a new order defaults to Pending', () {
      final o = OrderModel(
        id: 'LAB-ABCD2345',
        clientName: 'n',
        clientId: 'i',
        supervisorName: 's',
        items: [item()],
        clientUid: 'anon1',
      );
      expect(o.status, OrderStatus.pending);
      expect(o.approvedBy, isNull);
      expect(o.transactionIds, isEmpty);
    });
  });

  group('TransactionModel order link', () {
    TransactionModel make({String? orderId}) => TransactionModel(
          id: 't',
          chemicalId: 'c1',
          chemicalName: 'HCl',
          categoryId: 'cat',
          type: TxType.stockOut,
          quantity: 0.5,
          unit: 'L',
          enteredQuantity: 500,
          enteredUnit: 'mL',
          balanceAfter: 2,
          orderId: orderId,
          date: DateTime(2026, 1, 1),
          createdBy: 'u',
          createdByName: 'Admin',
        );

    test('manual entries have no orderId; order entries carry it', () {
      expect(make().orderId, isNull);
      expect(make(orderId: 'LAB-ABCD2345').orderId, 'LAB-ABCD2345');
    });

    test('order issues use the existing usage type (OUT)', () {
      expect(make().type.wire, 'OUT');
    });
  });
}
