import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/chemical_model.dart';
import '../../widgets/stock_chip.dart';
import '../models/cart_line.dart';
import '../providers/client_cart_provider.dart';

/// A chemical as the client sees it: the laboratory's "file card" look (status bar,
/// name + formula, mono quantity, stock chip) with an Add-to-cart action instead of
/// the staff-only details. [chemical] comes straight from the live Firestore stream.
class ClientChemicalCard extends ConsumerWidget {
  const ClientChemicalCard({super.key, required this.chemical, this.categoryName});
  final ChemicalModel chemical;

  /// Shown under the name (used by search results, which span several folders).
  final String? categoryName;

  void _add(BuildContext context, WidgetRef ref) {
    ref.read(cartProvider.notifier).add(chemical);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${chemical.name} added to cart'),
        action: SnackBarAction(
          label: 'View cart',
          textColor: AppColors.primaryFixed,
          onPressed: () => context.push('/cart'),
        ),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = chemical;
    final line = ref.watch(
        cartProvider.select((lines) => lines.firstWhereOrNull((l) => l.chemicalId == c.id)));
    final depleted = c.status == StockStatus.depleted;
    final bar = statusColor(c.status);
    final qtyColor = c.status == StockStatus.normal ? AppColors.onSurface : bar;

    return Container(
      decoration: AppDeco.card(),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(
          left: 0,
          top: 12,
          bottom: 12,
          child: Container(
            width: c.status == StockStatus.normal ? 4 : 6,
            decoration: BoxDecoration(
                color: bar, borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(c.name, style: AppText.titleMd),
                    if (c.formula.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(Fmt.formula(c.formula),
                            style: AppText.monoMd
                                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                  if ((categoryName ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(categoryName!,
                          style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('AVAILABLE',
                    style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
                Text.rich(TextSpan(
                  text: CartRules.fmt(c.currentStock),
                  style: AppText.monoLg
                      .copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: qtyColor),
                  children: [
                    TextSpan(
                        text: ' ${c.unit}',
                        style: AppText.monoSm
                            .copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w400)),
                  ],
                )),
                const SizedBox(height: 2),
                StockChip(c.status),
              ]),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: line == null
                    ? const SizedBox.shrink()
                    : Row(children: [
                        const Icon(Icons.check_circle, size: 14, color: AppColors.tertiary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('In cart: ${CartRules.withUnit(line.quantity, line.unit)}',
                              overflow: TextOverflow.ellipsis,
                              style: AppText.monoSm
                                  .copyWith(color: AppColors.tertiary, fontWeight: FontWeight.w600)),
                        ),
                      ]),
              ),
              const SizedBox(width: 8),
              if (line != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  onPressed: () => ref.read(cartProvider.notifier).remove(c.id),
                  icon: const Icon(Icons.remove_shopping_cart_outlined, size: 16),
                  label: const Text('Remove'),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
                  onPressed: depleted ? null : () => _add(context, ref),
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: Text(depleted ? 'Out of stock' : 'Add'),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
