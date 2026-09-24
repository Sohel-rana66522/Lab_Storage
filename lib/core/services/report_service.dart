import '../../models/category_model.dart';
import '../../models/chemical_model.dart';
import '../../models/transaction_model.dart';
import '../utils/formatters.dart';

enum ReportType {
  consumptionByDate('By date', 'Chemical consumption by date', true),
  consumptionByStudent('By student', 'Chemical consumption by student', true),
  consumptionByCategory('By category', 'Chemical consumption by category', true),
  stockReceived('Stock received', 'Chemical stock received', true),
  currentStock('Current stock', 'Current stock', false),
  lowStock('Low stock', 'Low-stock chemicals', false);

  const ReportType(this.chip, this.title, this.usesDateRange);
  final String chip;
  final String title;
  final bool usesDateRange;
}

class ReportTable {
  const ReportTable(this.headers, this.rows, {this.summary = ''});
  final List<String> headers;
  final List<List<String>> rows;
  final String summary;
}

/// Pure functions: no Flutter, no Firebase. Quantities of different units are never added
/// together; totals are kept per unit ("1.5 L · 200 g").
class ReportService {
  ReportService._();

  static String _totals(Map<String, double> byUnit) {
    if (byUnit.isEmpty) return '—';
    final keys = byUnit.keys.toList()..sort();
    return keys.map((u) => Fmt.withUnit(byUnit[u]!, u)).join(' · ');
  }

  static void _add(Map<String, double> m, String unit, double q) =>
      m[unit] = (m[unit] ?? 0) + q;

  static ReportTable build({
    required ReportType type,
    required List<TransactionModel> entries,
    required List<ChemicalModel> chemicals,
    required List<CategoryModel> categories,
  }) {
    final catName = {for (final c in categories) c.id: c.name};
    switch (type) {
      case ReportType.consumptionByDate:
        return _byDate(entries);
      case ReportType.consumptionByStudent:
        return _byStudent(entries);
      case ReportType.consumptionByCategory:
        return _byCategory(entries, catName);
      case ReportType.stockReceived:
        return _received(entries);
      case ReportType.currentStock:
        return _stock(chemicals, catName, onlyLow: false);
      case ReportType.lowStock:
        return _stock(chemicals, catName, onlyLow: true);
    }
  }

  static ReportTable _byDate(List<TransactionModel> entries) {
    final days = <DateTime, _Agg>{};
    for (final t in entries.where((t) => !t.isIn)) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      final a = days[d] ??= _Agg();
      a.count++;
      _add(a.totals, t.unit, t.quantity);
    }
    final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
    return ReportTable(
      const ['Date', 'Entries', 'Total used'],
      [for (final k in keys) [Fmt.date(k), '${days[k]!.count}', _totals(days[k]!.totals)]],
      summary: '${keys.length} day(s) with usage',
    );
  }

  static ReportTable _byStudent(List<TransactionModel> entries) {
    final map = <String, _Agg>{};
    for (final t in entries.where((t) => !t.isIn)) {
      final name = (t.studentName ?? 'Unknown').trim();
      final id = (t.studentId ?? '').trim();
      final key = id.isEmpty ? name : '$name ($id)';
      final a = map[key] ??= _Agg();
      a.count++;
      _add(a.totals, t.unit, t.quantity);
    }
    final keys = map.keys.toList()..sort((a, b) => map[b]!.count.compareTo(map[a]!.count));
    return ReportTable(
      const ['Student', 'Entries', 'Total used'],
      [for (final k in keys) [k, '${map[k]!.count}', _totals(map[k]!.totals)]],
      summary: '${keys.length} student(s)',
    );
  }

  static ReportTable _byCategory(List<TransactionModel> entries, Map<String, String> catName) {
    final map = <String, _Agg>{};
    for (final t in entries.where((t) => !t.isIn)) {
      final key = catName[t.categoryId] ?? 'Uncategorised';
      final a = map[key] ??= _Agg();
      a.count++;
      _add(a.totals, t.unit, t.quantity);
    }
    final keys = map.keys.toList()..sort();
    return ReportTable(
      const ['Category', 'Entries', 'Total used'],
      [for (final k in keys) [k, '${map[k]!.count}', _totals(map[k]!.totals)]],
      summary: '${keys.length} categor${keys.length == 1 ? 'y' : 'ies'}',
    );
  }

  static ReportTable _received(List<TransactionModel> entries) {
    final ins = entries.where((t) => t.isIn).toList();
    final totals = <String, double>{};
    for (final t in ins) {
      _add(totals, t.unit, t.quantity);
    }
    return ReportTable(
      const ['Date', 'Chemical', 'Quantity', 'Supplier', 'Reference', 'Recorded by'],
      [
        for (final t in ins)
          [
            Fmt.date(t.date),
            t.chemicalName,
            Fmt.withUnit(t.quantity, t.unit),
            t.supplier ?? (t.isInitial ? 'Initial stock' : '—'),
            t.referenceNumber ?? '—',
            t.createdByName,
          ]
      ],
      summary: '${ins.length} receipt(s) • ${_totals(totals)}',
    );
  }

  static ReportTable _stock(List<ChemicalModel> chemicals, Map<String, String> catName,
      {required bool onlyLow}) {
    final list = chemicals.where((c) => !onlyLow || c.isLow).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    String status(ChemicalModel c) => switch (c.status) {
          StockStatus.normal => 'In stock',
          StockStatus.low => 'Low',
          StockStatus.depleted => 'Depleted',
        };
    return ReportTable(
      const ['Chemical', 'Formula', 'Category', 'Current', 'Minimum', 'Status'],
      [
        for (final c in list)
          [
            c.name,
            c.formula.isEmpty ? '—' : Fmt.formula(c.formula),
            catName[c.categoryId] ?? 'Uncategorised',
            Fmt.withUnit(c.currentStock, c.unit),
            Fmt.withUnit(c.minimumStock, c.unit),
            status(c),
          ]
      ],
      summary: '${list.length} chemical(s)',
    );
  }
}

class _Agg {
  int count = 0;
  final Map<String, double> totals = {};
}
