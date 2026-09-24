import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/report_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/csv.dart';
import '../../core/utils/formatters.dart';
import '../../models/category_model.dart';
import '../../models/chemical_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/common_states.dart';

/// Staff-only reports with date-range filtering, kept visually consistent with the rest
/// of the ledger (hairline table, mono numerals).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportType _type = ReportType.consumptionByDate;
  late DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  late DateTime _to = DateTime.now();

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chems = ref.watch(chemicalsProvider).valueOrNull ?? const <ChemicalModel>[];
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const <CategoryModel>[];
    final rangeAsync = _type.usesDateRange
        ? ref.watch(rangeTransactionsProvider((_from, _to)))
        : const AsyncData<List<TransactionModel>>([]);

    return PageContainer(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Text('Reports', style: AppText.headlineSm),
        const SizedBox(height: 4),
        Text('Consumption, receipts and stock levels across the archive.',
            style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in ReportType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(t.chip),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: AppColors.primary,
                    labelStyle: AppText.monoSm.copyWith(
                        color: _type == t ? Colors.white : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600),
                    backgroundColor: AppColors.surfaceContainer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999), side: BorderSide.none),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_type.usesDateRange)
          InkWell(
            onTap: _pickRange,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: AppDeco.card(radius: 8),
              child: Row(children: [
                const Icon(Icons.date_range, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('${Fmt.date(_from)} — ${Fmt.date(_to)}', style: AppText.monoMd)),
                const Icon(Icons.expand_more, size: 18, color: AppColors.outline),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        if (_type.usesDateRange)
          AsyncBody<List<TransactionModel>>(value: rangeAsync, data: (entries) => _table(entries, chems, cats))
        else
          _table(const [], chems, cats),
      ]),
    );
  }

  Widget _table(List<TransactionModel> entries, List<ChemicalModel> chems, List<CategoryModel> cats) {
    final table = ReportService.build(type: _type, entries: entries, chemicals: chems, categories: cats);
    if (table.rows.isEmpty) {
      return const EmptyState(icon: Icons.summarize_outlined, title: 'Nothing to report', message: 'No data for this selection.');
    }
    return Container(
      decoration: AppDeco.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            Expanded(child: Text(table.summary, style: AppText.titleSm)),
            TextButton.icon(
              onPressed: () => copyCsv(context, toCsv(table.headers, table.rows), label: _type.title),
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('CSV'),
            ),
          ]),
        ),
        const Divider(height: 1, color: AppColors.surfaceContainer),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.surfaceContainer),
            headingTextStyle: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700),
            dataTextStyle: AppText.bodyMd.copyWith(fontSize: 13),
            columns: [for (final h in table.headers) DataColumn(label: Text(h))],
            rows: [
              for (final r in table.rows) DataRow(cells: [for (final v in r) DataCell(Text(v))]),
            ],
          ),
        ),
      ]),
    );
  }
}
