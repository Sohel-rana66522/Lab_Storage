import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/common_states.dart';
import '../../widgets/ledger_tile.dart';

class RecentsScreen extends ConsumerWidget {
  const RecentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransactionsProvider);

    return PageContainer(
      child: AsyncBody<List<TransactionModel>>(
        value: recent,
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No activity yet',
              message: 'Stock received and usage recorded will show up here.',
            );
          }
          final groups = <String, List<TransactionModel>>{};
          for (final t in list) {
            (groups[Fmt.day(t.sortTime)] ??= []).add(t);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                  child: Text(entry.key.toUpperCase(),
                      style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
                ),
                Container(
                  decoration: AppDeco.card(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (var i = 0; i < entry.value.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.surfaceContainer),
                      LedgerTile(
                        entry: entry.value[i],
                        onTap: () => context.push('/chemicals/${entry.value[i].chemicalId}'),
                      ),
                    ],
                  ]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
