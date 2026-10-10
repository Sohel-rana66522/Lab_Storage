import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../models/cart_line.dart';
import '../providers/client_cart_provider.dart';

/// "Order Summary": each selected chemical and the amount requested.
class OrderSummary extends StatelessWidget {
  const OrderSummary({super.key, required this.entries});
  final List<CartEntry> entries;

  @override
  Widget build(BuildContext context) => Container(
        decoration: AppDeco.card(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.secondary),
            const SizedBox(width: 6),
            Text('Order Summary', style: AppText.titleMd),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: AppColors.surfaceContainer),
            _Row(entry: entries[i]),
          ],
          const Divider(height: 24, color: AppColors.hairline),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total items', style: AppText.titleSm),
            Text('${entries.length}',
                style: AppText.monoLg.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});
  final CartEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = entry.chemical;
    final line = entry.line;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c?.name ?? 'Unavailable chemical', style: AppText.titleSm),
          if (c != null && c.formula.isNotEmpty)
            Text(Fmt.formula(c.formula),
                style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
        ]),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('Requested', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        Text(CartRules.withUnit(line.quantity, line.unit),
            style: AppText.monoLg.copyWith(
                fontWeight: FontWeight.w700,
                color: entry.error == null ? AppColors.onSurface : AppColors.error)),
      ]),
    ]);
  }
}
