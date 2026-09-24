import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/chemical_model.dart';
import 'common_states.dart';
import 'stock_chip.dart';

/// A chemical "file" card (Stitch "Chemical Document Entry Card"): left status bar, name +
/// formula, balance, gauge and a footer with storage location / last entry.
class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.chemical, required this.onTap, this.compact = false});
  final ChemicalModel chemical;
  final VoidCallback onTap;

  /// Grid tiles drop the last-entry footer detail to stay tidy.
  final bool compact;

  Color get _bar => switch (chemical.status) {
        StockStatus.normal => AppColors.primary,
        StockStatus.low => AppColors.warnFg,
        StockStatus.depleted => AppColors.critFg,
      };

  Widget _footerRight() {
    final c = chemical;
    if (c.status == StockStatus.depleted) {
      return Text('Reorder needed',
          style: AppText.monoSm.copyWith(color: AppColors.critFg, fontWeight: FontWeight.w700));
    }
    if (c.status == StockStatus.low) {
      final gap = c.minimumStock - c.currentStock;
      return Text('Min: ${Fmt.withUnit(c.minimumStock, c.unit)} (Δ -${Fmt.qty(gap)} ${c.unit})',
          style: AppText.monoSm.copyWith(color: AppColors.warnFg, fontWeight: FontWeight.w700));
    }
    final at = c.lastEntryAt, delta = c.lastEntryDelta;
    if (at == null || delta == null) return const SizedBox.shrink();
    final neg = delta < 0;
    return Text(
      '${Fmt.day(at)} ${Fmt.signed(delta.abs(), c.unit, negative: neg)}',
      style: AppText.monoSm.copyWith(
          color: neg ? AppColors.error : AppColors.tertiary, fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = chemical;
    final subtitle = [c.grade, c.description].whereType<String>().where((s) => s.isNotEmpty);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: AppDeco.card(),
          child: Stack(children: [
            Positioned(
              left: 0,
              top: 12,
              bottom: 12,
              child: Container(
                width: c.status == StockStatus.normal ? 4 : 6,
                decoration: BoxDecoration(
                    color: _bar,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))),
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
                      if (subtitle.isNotEmpty && !compact)
                        Text(subtitle.join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text.rich(TextSpan(
                      text: Fmt.qty(c.currentStock),
                      style: AppText.monoLg.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: statusColor(c.status) == AppColors.primary
                              ? AppColors.onSurface
                              : statusColor(c.status)),
                      children: [
                        TextSpan(
                            text: ' ${c.unit}',
                            style: AppText.monoSm.copyWith(
                                color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w400)),
                      ],
                    )),
                    const SizedBox(height: 2),
                    StockChip(c.status),
                  ]),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: c.gaugeRatio,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceContainer,
                    valueColor: AlwaysStoppedAnimation(_bar),
                  ),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Row(children: [
                      const Icon(Icons.place_outlined, size: 14, color: AppColors.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (c.location?.isNotEmpty ?? false)
                              ? c.location!
                              : (c.casNumber?.isNotEmpty ?? false)
                                  ? 'CAS: ${c.casNumber}'
                                  : 'No location set',
                          overflow: TextOverflow.ellipsis,
                          style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  _footerRight(),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Small avatar-ish hazard tag used in the chemical header.
class HazardPill extends StatelessWidget {
  const HazardPill(this.hazard, {super.key});
  final String hazard;

  @override
  Widget build(BuildContext context) => Pill(hazard.toUpperCase(),
      bg: AppColors.errorContainer, fg: AppColors.onErrorContainer, icon: Icons.warning_amber_rounded, radius: 4);
}
