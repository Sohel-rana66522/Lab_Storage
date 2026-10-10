import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/units.dart';
import '../../widgets/lab_inputs.dart';
import '../models/cart_line.dart';
import '../providers/client_cart_provider.dart';

/// One chemical in the cart: live availability, a − / + quantity stepper with a typed
/// value, a unit switch (e.g. L ↔ mL) and a remove button.
class CartItemCard extends ConsumerStatefulWidget {
  const CartItemCard({super.key, required this.entry});
  final CartEntry entry;

  @override
  ConsumerState<CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends ConsumerState<CartItemCard> {
  late final TextEditingController _qty =
      TextEditingController(text: CartRules.fmt(widget.entry.line.quantity));

  @override
  void didUpdateWidget(covariant CartItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the text box in step with the cart when the value changed from elsewhere
    // (− / + buttons, unit conversion) but leave it alone while the user is typing.
    final typed = parseDecimal(_qty.text) ?? 0;
    final actual = widget.entry.line.quantity;
    if ((typed - actual).abs() > 1e-9) _qty.text = CartRules.fmt(actual);
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Widget _stepButton(IconData icon, VoidCallback? onPressed, String tooltip) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(icon, size: 18),
        color: AppColors.primary,
      );

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final line = entry.line;
    final c = entry.chemical;
    final notifier = ref.read(cartProvider.notifier);

    if (c == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: AppDeco.card(),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text('This chemical is no longer available.',
                style: AppText.bodyMd.copyWith(color: AppColors.error)),
          ),
          TextButton(
              onPressed: () => notifier.remove(line.chemicalId), child: const Text('Remove')),
        ]),
      );
    }

    final options = CartRules.unitOptions(c);
    final step = CartRules.step(line.unit);
    final max = CartRules.maxIn(c, line.unit);
    final error = entry.error;
    final canMinus = line.quantity > step + 1e-9;
    final canPlus = line.quantity + 1e-9 < max;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDeco.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
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
          ),
          IconButton(
            tooltip: 'Remove from cart',
            visualDensity: VisualDensity.compact,
            onPressed: () => notifier.remove(c.id),
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.onSurfaceVariant),
          ),
        ]),
        const SizedBox(height: 2),
        Text('Available: ${CartRules.withUnit(c.currentStock, c.unit)}',
            style: AppText.monoMd.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 10),
        Text('QUANTITY',
            style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Row(children: [
          Container(
            decoration: BoxDecoration(
                color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _stepButton(
                Icons.remove,
                canMinus
                    ? () => notifier.setQuantity(c.id, Units.round(line.quantity - step))
                    : null,
                'Decrease',
              ),
              SizedBox(
                width: 92,
                child: TextField(
                  controller: _qty,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    ...decimalInputFormatters,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  style: AppText.monoLg.copyWith(fontWeight: FontWeight.w700),
                  onChanged: (v) => notifier.setQuantity(c.id, parseDecimal(v) ?? 0),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    enabledBorder: error != null
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.error))
                        : null,
                  ),
                ),
              ),
              _stepButton(
                Icons.add,
                canPlus
                    ? () {
                        final next = Units.round(line.quantity + step);
                        notifier.setQuantity(c.id, next > max ? max : next);
                      }
                    : null,
                'Increase',
              ),
            ]),
          ),
          const SizedBox(width: 10),
          if (options.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  border: Border.all(color: AppColors.hairline),
                  borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: options.contains(line.unit) ? line.unit : options.first,
                  isDense: true,
                  style: AppText.monoLg,
                  borderRadius: BorderRadius.circular(8),
                  dropdownColor: AppColors.surfaceLowest,
                  items: [
                    for (final u in options) DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (u) {
                    if (u != null) notifier.setUnit(c, u);
                  },
                ),
              ),
            )
          else
            Text(c.unit, style: AppText.monoLg.copyWith(color: AppColors.onSurfaceVariant)),
        ]),
        if (error != null) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline, size: 14, color: AppColors.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(error, style: AppText.bodySm.copyWith(color: AppColors.error)),
            ),
          ]),
        ],
      ]),
    );
  }
}
