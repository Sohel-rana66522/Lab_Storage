import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/csv.dart';
import '../../core/utils/formatters.dart';
import '../../models/chemical_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/chemical_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/chemical_header.dart';
import '../../widgets/common_states.dart';
import '../../widgets/transaction_table.dart';
import '../transactions/entry_sheet.dart';

/// One physical entry-book page, digitized: header metrics + full transaction ledger.
class ChemicalDetailScreen extends ConsumerWidget {
  const ChemicalDetailScreen({super.key, required this.chemicalId});
  final String chemicalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chemAsync = ref.watch(chemicalProvider(chemicalId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/folders'),
        ),
        title: chemAsync.valueOrNull == null
            ? const Text('Chemical file')
            : Text(chemAsync.value!.name, overflow: TextOverflow.ellipsis, style: AppText.titleMd),
        actions: [
          if (chemAsync.valueOrNull != null)
            IconButton(
              tooltip: 'Edit chemical',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/chemicals/$chemicalId/edit'),
            ),
        ],
      ),
      floatingActionButton: chemAsync.valueOrNull != null
          ? _actionFabs(context, chemAsync.value!)
          : null,
      body: SafeArea(
        child: AsyncBody<ChemicalModel?>(
          value: chemAsync,
          data: (chem) {
            if (chem == null) {
              return EmptyState(
                icon: Icons.folder_off_outlined,
                title: 'Chemical not found',
                message: 'It may have been removed.',
                actionLabel: 'Back to folders',
                onAction: () => context.go('/folders'),
              );
            }
            return PageContainer(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  ChemicalHeader(chemical: chem),
                  const SizedBox(height: 12),
                  if ((chem.description ?? '').isNotEmpty || (chem.notes ?? '').isNotEmpty)
                    _notesCard(chem),
                  _historyCard(context, ref, chem),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _actionFabs(BuildContext context, ChemicalModel chem) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'usage',
            onPressed: () => showEntrySheet(context, chem, initial: TxType.stockOut),
            backgroundColor: AppColors.surfaceLowest,
            foregroundColor: AppColors.error,
            elevation: 1,
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Usage'),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'stock',
            onPressed: () => showEntrySheet(context, chem, initial: TxType.stockIn),
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: Colors.white,
            elevation: 2,
            icon: const Icon(Icons.add),
            label: const Text('Add Stock'),
          ),
        ],
      );

  Widget _notesCard(ChemicalModel chem) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: AppDeco.card(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((chem.description ?? '').isNotEmpty) ...[
              Text('DESCRIPTION', style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text(chem.description!, style: AppText.bodyMd),
            ],
            if ((chem.notes ?? '').isNotEmpty) ...[
              if ((chem.description ?? '').isNotEmpty) const SizedBox(height: 10),
              Text('HANDLING NOTES', style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text(chem.notes!, style: AppText.bodyMd),
            ],
          ]),
        ),
      );

  Widget _historyCard(BuildContext context, WidgetRef ref, ChemicalModel chem) {
    final entries = ref.watch(chemicalEntriesProvider(chemicalId));
    return Container(
      decoration: AppDeco.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.secondary),
            const SizedBox(width: 6),
            Expanded(
                child: Text('Entry History', style: AppText.titleMd)),
            entries.maybeWhen(
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Export CSV',
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      onPressed: () => copyCsv(context, _csv(list), label: '${chem.name} ledger'),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ]),
        ),
        const Divider(height: 1, color: AppColors.surfaceContainer),
        AsyncBody<List<TransactionModel>>(
          value: entries,
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.history_toggle_off,
                title: 'No entries yet',
                message: 'Add stock or record usage to start this file\'s history.',
              );
            }
            return TransactionTable(entries: list);
          },
        ),
      ]),
    );
  }

  String _csv(List<TransactionModel> list) => toCsv(
        ['Date', 'Type', 'Description/Student', 'Added', 'Used', 'Balance', 'Recorded by'],
        [
          for (final t in list)
            [
              Fmt.date(t.date),
              t.isIn ? 'IN' : 'OUT',
              t.isIn ? (t.isInitial ? 'Initial Stock' : (t.supplier ?? '')) : (t.studentName ?? ''),
              t.isIn ? Fmt.qty(t.quantity) : '',
              t.isIn ? '' : Fmt.qty(t.quantity),
              Fmt.qty(t.balanceAfter),
              t.createdByName,
            ]
        ],
      );
}
