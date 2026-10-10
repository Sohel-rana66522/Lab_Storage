import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/chemical_provider.dart';
import '../../widgets/common_states.dart';
import '../providers/client_cart_provider.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/client_ui.dart';

/// "My Chemical Cart": review what was selected, adjust quantities, then proceed.
/// Everything here is local; Firestore is only read (for live availability).
class ClientCartPage extends ConsumerWidget {
  const ClientCartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(cartEntriesProvider);

    return PageContainer(
      maxWidth: 760,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Row(children: [
          SquareIconButton(
              icon: Icons.arrow_back, tooltip: 'Back', onTap: () => popOrGo(context, '/')),
          const SizedBox(width: 8),
          Text('My Chemical Cart', style: AppText.headlineSm),
        ]),
        const SizedBox(height: 12),
        AsyncBody<List<CartEntry>>(
          value: entries,
          onRetry: () => ref.invalidate(chemicalsProvider),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Your cart is empty',
                message: 'Open a folder and add the chemicals you need.',
                actionLabel: 'Browse Folders',
                onAction: () => context.go('/'),
              );
            }
            final blocked = list.any((e) => e.error != null);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final e in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CartItemCard(key: ValueKey(e.line.chemicalId), entry: e),
                ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDeco.card(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Total Items', style: AppText.titleMd),
                    Text('${list.length}',
                        style: AppText.monoLg.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
                  ]),
                  if (blocked) ...[
                    const SizedBox(height: 8),
                    Text('Fix the items marked in red before you continue.',
                        style: AppText.bodySm.copyWith(color: AppColors.error)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: blocked ? null : () => context.go('/order'),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Proceed to Order'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Add more chemicals'),
                  ),
                ]),
              ),
            ]);
          },
        ),
      ]),
    );
  }
}
