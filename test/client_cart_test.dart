import 'package:flutter_test/flutter_test.dart';
import 'package:lab_ledger/client/models/cart_line.dart';
import 'package:lab_ledger/client/models/order_model.dart';
import 'package:lab_ledger/client/repositories/order_repository.dart';
import 'package:lab_ledger/client/widgets/client_search_results.dart';
import 'package:lab_ledger/models/chemical_model.dart';

ChemicalModel chem({String unit = 'L', double stock = 2.5, String name = 'Hydrochloric Acid'}) =>
    ChemicalModel(
      id: 'c1',
      name: name,
      formula: 'HCl',
      categoryId: 'cat1',
      unit: unit,
      currentStock: stock,
    );

void main() {
  group('CartRules.validate', () {
    test('accepts a quantity within stock', () {
      expect(CartRules.validate(chem(), const CartLine(chemicalId: 'c1', quantity: 1, unit: 'L')), isNull);
    });

    test('accepts a smaller unit that converts within stock (500 mL of 2.5 L)', () {
      expect(CartRules.validate(chem(), const CartLine(chemicalId: 'c1', quantity: 500, unit: 'mL')), isNull);
    });

    test('accepts exactly the whole stock, also across units', () {
      expect(CartRules.validate(chem(), const CartLine(chemicalId: 'c1', quantity: 2.5, unit: 'L')), isNull);
      expect(CartRules.validate(chem(), const CartLine(chemicalId: 'c1', quantity: 2500, unit: 'mL')), isNull);
    });

    test('rejects more than is available', () {
      final msg = CartRules.validate(chem(), const CartLine(chemicalId: 'c1', quantity: 2.6, unit: 'L'));
      expect(msg, isNotNull);
      expect(msg, contains('2.5 L'));
      expect(CartRules.validate(chem(), const CartLine(chemicalId: 'c1', quantity: 2501, unit: 'mL')), isNotNull);
    });

    test('rejects zero, negative and non-finite quantities', () {
      for (final q in [0.0, -1.0, double.nan, double.infinity]) {
        expect(CartRules.validate(chem(), CartLine(chemicalId: 'c1', quantity: q, unit: 'L')), isNotNull,
            reason: 'quantity $q');
      }
    });

    test('rejects an incompatible unit', () {
      expect(CartRules.validate(chem(), const CartLine(chemicalId: 'c1', quantity: 1, unit: 'g')), isNotNull);
    });

    test('rejects anything when the chemical is out of stock', () {
      final msg = CartRules.validate(
          chem(stock: 0), const CartLine(chemicalId: 'c1', quantity: 1, unit: 'L'));
      expect(msg, contains('out of stock'));
    });

    test('mass units work too (kg stock, g request)', () {
      final c = chem(unit: 'kg', stock: 0.25);
      expect(CartRules.validate(c, const CartLine(chemicalId: 'c1', quantity: 250, unit: 'g')), isNull);
      expect(CartRules.validate(c, const CartLine(chemicalId: 'c1', quantity: 251, unit: 'g')), isNotNull);
    });
  });

  group('CartRules helpers', () {
    test('toBase converts into the unit the laboratory tracks', () {
      expect(CartRules.toBase(chem(), 500, 'mL'), 0.5);
      expect(CartRules.toBase(chem(), 1.5, 'L'), 1.5);
    });

    test('maxIn expresses the whole stock in the chosen unit', () {
      expect(CartRules.maxIn(chem(), 'mL'), 2500);
      expect(CartRules.maxIn(chem(), 'L'), 2.5);
      expect(CartRules.maxIn(chem(), 'g'), 0); // incompatible
    });

    test('unitOptions offers every unit of the same dimension', () {
      expect(CartRules.unitOptions(chem()), ['L', 'mL']);
      expect(CartRules.unitOptions(chem(unit: 'kg')), ['kg', 'g', 'mg']);
    });

    test('defaultQuantity is one step, capped at what is left', () {
      expect(CartRules.defaultQuantity(chem(stock: 2.5)), 0.5);
      expect(CartRules.defaultQuantity(chem(stock: 0.2)), 0.2);
    });

    test('fmt drops trailing zeros', () {
      expect(CartRules.fmt(500), '500');
      expect(CartRules.fmt(0.5), '0.5');
      expect(CartRules.fmt(2.50), '2.5');
      expect(CartRules.fmt(100), '100');
      expect(CartRules.fmt(0), '0');
      expect(CartRules.withUnit(2.5, 'L'), '2.5 L');
    });
  });

  group('CartLine storage', () {
    test('round-trips through json', () {
      const line = CartLine(chemicalId: 'abc', quantity: 0.5, unit: 'L');
      final back = CartLine.tryParse(line.toJson());
      expect(back?.chemicalId, 'abc');
      expect(back?.quantity, 0.5);
      expect(back?.unit, 'L');
    });

    test('ignores malformed saved data instead of throwing', () {
      expect(CartLine.tryParse('nope'), isNull);
      expect(CartLine.tryParse({'id': '', 'q': 1, 'u': 'L'}), isNull);
      expect(CartLine.tryParse({'id': 'a', 'q': 'x', 'u': 'L'}), isNull);
      expect(CartLine.tryParse({'id': 'a', 'q': 1}), isNull);
    });
  });

  group('Order ids and items', () {
    test('order ids match the format the security rules require', () {
      final rule = RegExp(r'^LAB-[A-HJ-NP-Z2-9]{8}$');
      for (var i = 0; i < 200; i++) {
        expect(rule.hasMatch(OrderRepository.newOrderId()), isTrue);
      }
    });

    test('order ids are not repeated', () {
      final ids = {for (var i = 0; i < 500; i++) OrderRepository.newOrderId()};
      expect(ids.length, 500);
    });

    test('OrderItem keeps the requested and the base quantity', () {
      const item = OrderItem(
        chemicalId: 'c1',
        chemicalName: 'Hydrochloric Acid',
        formula: 'HCl',
        requestedQuantity: 500,
        unit: 'mL',
        categoryId: 'cat1',
        categoryName: 'Acids',
        baseQuantity: 0.5,
        baseUnit: 'L',
        availableAtRequest: 2.5,
      );
      final map = item.toMap();
      expect(map['requestedQuantity'], 500);
      expect(map['unit'], 'mL');
      expect(map['baseQuantity'], 0.5);
      expect(map['baseUnit'], 'L');
      final back = OrderItem.fromMap(map);
      expect(back.chemicalName, 'Hydrochloric Acid');
      expect(back.categoryName, 'Acids');
    });

    test('new orders start as Pending', () {
      expect(OrderStatus.pending, 'Pending');
    });
  });

  group('Search', () {
    test('formulas match with or without subscripts', () {
      expect(normalizeForSearch('H₂SO₄'), 'h2so4');
      expect(normalizeForSearch('H2SO4'), 'h2so4');
      expect(normalizeForSearch('Ca(OH)₂'), 'ca(oh)2');
    });
  });
}
