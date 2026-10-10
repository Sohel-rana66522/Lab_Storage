import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/units.dart';
import '../../models/chemical_model.dart';
import '../../providers/chemical_provider.dart';
import '../models/cart_line.dart';

/// Overridden in `main_client.dart` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden.'),
);

/// The client's cart. It lives on this device only (browser storage) so a page refresh
/// keeps it. Adding to or changing the cart NEVER writes to Firestore.
class CartNotifier extends Notifier<List<CartLine>> {
  static const _storageKey = 'lab_ledger_client_cart_v1';

  @override
  List<CartLine> build() {
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final seen = <String>{};
      return [
        for (final item in decoded)
          if (CartLine.tryParse(item) case final line? when seen.add(line.chemicalId)) line,
      ];
    } catch (_) {
      return const []; // corrupt storage must never stop the portal from opening
    }
  }

  void _set(List<CartLine> next) {
    state = next;
    try {
      unawaited(ref
          .read(sharedPreferencesProvider)
          .setString(_storageKey, jsonEncode(next.map((l) => l.toJson()).toList())));
    } catch (_) {
      // Persistence is a convenience; the in-memory cart still works.
    }
  }

  bool contains(String chemicalId) => state.any((l) => l.chemicalId == chemicalId);

  /// Adds the chemical with a sensible starting quantity. Out-of-stock chemicals are ignored.
  void add(ChemicalModel c) {
    if (contains(c.id) || c.currentStock <= 0) return;
    _set([
      ...state,
      CartLine(chemicalId: c.id, quantity: CartRules.defaultQuantity(c), unit: c.unit),
    ]);
  }

  void remove(String chemicalId) =>
      _set([for (final l in state) if (l.chemicalId != chemicalId) l]);

  /// Sets the requested amount as typed. Validity is reported by [CartRules.validate]
  /// and enforced again when the order is submitted.
  void setQuantity(String chemicalId, double quantity) => _set([
        for (final l in state)
          if (l.chemicalId == chemicalId) l.copyWith(quantity: quantity) else l,
      ]);

  /// Switches unit and converts the amount so the physical quantity stays the same.
  void setUnit(ChemicalModel c, String unit) => _set([
        for (final l in state)
          if (l.chemicalId == c.id && l.unit != unit && Units.isCompatible(l.unit, unit))
            l.copyWith(quantity: Units.convert(l.quantity, l.unit, unit), unit: unit)
          else
            l,
      ]);

  void clear() => _set(const []);
}

final cartProvider = NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);

/// Number of different chemicals in the cart (what the cart badge shows).
final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).length);

/// A cart line joined with the chemical's live Firestore record.
class CartEntry {
  const CartEntry({required this.line, required this.chemical});
  final CartLine line;

  /// Null when the chemical was removed from the laboratory's records.
  final ChemicalModel? chemical;

  String? get error {
    final c = chemical;
    if (c == null) return 'This chemical is no longer available.';
    return CartRules.validate(c, line);
  }
}

final cartEntriesProvider = Provider<AsyncValue<List<CartEntry>>>((ref) {
  final lines = ref.watch(cartProvider);
  return ref.watch(chemicalsProvider).whenData((all) {
    final byId = {for (final c in all) c.id: c};
    return [for (final l in lines) CartEntry(line: l, chemical: byId[l.chemicalId])];
  });
});
