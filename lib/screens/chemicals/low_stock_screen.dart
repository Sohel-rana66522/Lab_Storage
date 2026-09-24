import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chemical_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../widgets/common_states.dart';
import '../../widgets/file_card.dart';

class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final low = ref.watch(lowStockProvider);
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final catName = {for (final c in cats) c.id: c.name};

    return PageContainer(
      child: AsyncBody<List<ChemicalModel>>(
        value: low,
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All stocked up',
              message: 'No chemical is at or below its minimum safe stock right now.',
            );
          }
          final depleted = list.where((c) => c.status == StockStatus.depleted).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warnFg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      '${list.length} chemical${list.length == 1 ? '' : 's'} need attention'
                      '${depleted > 0 ? ' • $depleted depleted' : ''}',
                      style: AppText.titleMd),
                ),
              ]),
              const SizedBox(height: 12),
              for (final c in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((catName[c.categoryId] ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(catName[c.categoryId]!.toUpperCase(),
                            style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.6)),
                      ),
                    FileCard(chemical: c, onTap: () => context.push('/chemicals/${c.id}')),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}
