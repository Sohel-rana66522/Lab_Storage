import '../../core/utils/units.dart';
import '../../models/chemical_model.dart';

/// One chemical the client has selected. It stores only what the client chose
/// (which chemical, how much, in which unit). Names and stock levels are always
/// joined live from Firestore, so the cart can never show stale availability.
class CartLine {
  const CartLine({required this.chemicalId, required this.quantity, required this.unit});

  final String chemicalId;
  final double quantity;
  final String unit;

  CartLine copyWith({double? quantity, String? unit}) => CartLine(
        chemicalId: chemicalId,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
      );

  Map<String, dynamic> toJson() => {'id': chemicalId, 'q': quantity, 'u': unit};

  /// Returns null for anything that is not a well-formed saved line.
  static CartLine? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final q = raw['q'];
    final u = raw['u'];
    if (id is! String || id.isEmpty || q is! num || u is! String || u.isEmpty) return null;
    final qty = q.toDouble();
    if (!qty.isFinite) return null;
    return CartLine(chemicalId: id, quantity: qty, unit: u);
  }
}

/// Quantity rules for the client portal. They reuse [Units] and the chemical's own
/// `currentStock` (the same figure the laboratory app maintains) rather than
/// calculating availability a second way.
class CartRules {
  CartRules._();

  static const _epsilon = 1e-9;

  /// Units a client may request this chemical in: every unit of the same dimension
  /// as the unit the laboratory tracks it in (e.g. L and mL).
  static List<String> unitOptions(ChemicalModel c) {
    final compatible = Units.compatible(c.unit);
    return compatible.isEmpty ? [c.unit] : compatible;
  }

  /// Size of one tap on the − / + buttons.
  static double step(String unit) => switch (unit) {
        'L' => 0.5,
        'mL' => 50.0,
        'kg' => 0.5,
        'g' => 10.0,
        'mg' => 100.0,
        _ => 1.0,
      };

  /// Quantity used when a chemical is first added: one step, or everything that is
  /// left if that is less than a step.
  static double defaultQuantity(ChemicalModel c) {
    final s = step(c.unit);
    return Units.round(c.currentStock < s ? c.currentStock : s);
  }

  /// The whole current stock expressed in [unit] (0 if the unit is not compatible).
  static double maxIn(ChemicalModel c, String unit) {
    if (unit == c.unit) return c.currentStock;
    if (!Units.isCompatible(unit, c.unit)) return 0;
    return Units.convert(c.currentStock, c.unit, unit);
  }

  /// [quantity] in [unit] converted to the unit the chemical is tracked in.
  static double toBase(ChemicalModel c, double quantity, String unit) {
    if (unit == c.unit) return Units.round(quantity);
    return Units.convert(quantity, unit, c.unit);
  }

  /// Why [line] cannot be ordered right now, or null if it is fine.
  static String? validate(ChemicalModel c, CartLine line) {
    if (!line.quantity.isFinite || line.quantity <= 0) {
      return 'Enter a quantity greater than zero.';
    }
    if (line.unit != c.unit && !Units.isCompatible(line.unit, c.unit)) {
      return '${c.name} cannot be requested in ${line.unit}.';
    }
    if (c.currentStock <= 0) return '${c.name} is currently out of stock.';
    final base = toBase(c, line.quantity, line.unit);
    if (base <= 0) return 'That quantity is too small.';
    if (base > c.currentStock + _epsilon) {
      return 'Only ${withUnit(c.currentStock, c.unit)} available.';
    }
    return null;
  }

  /// 500 -> "500", 0.5 -> "0.5", 2.50 -> "2.5" (up to 6 decimals, no trailing zeros).
  static String fmt(double v) {
    final s = Units.round(v).toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String withUnit(double v, String unit) => '${fmt(v)} $unit';
}
