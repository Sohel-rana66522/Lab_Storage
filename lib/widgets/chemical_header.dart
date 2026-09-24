import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/chemical_model.dart';
import '../models/transaction_model.dart';
import 'common_states.dart';
import 'file_card.dart';

/// The top of a chemical "file": folio tab, name/formula, and the three key metrics.
class ChemicalHeader extends StatelessWidget {
  const ChemicalHeader({super.key, required this.chemical, this.latest});
  final ChemicalModel chemical;

  /// Most recent ledger entry (for "Last Entry" details).
  final TransactionModel? latest;

  @override
  Widget build(BuildContext context) {
    final c = chemical;
    return Container(
      decoration: AppDeco.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: AppColors.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(
              child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('REAGENT FOLIO #${c.id.substring(0, c.id.length < 6 ? c.id.length : 6).toUpperCase()}',
                    style: AppText.monoSm.copyWith(
                        color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700)),
                if (c.hazardClass != null && c.hazardClass!.isNotEmpty) HazardPill(c.hazardClass!),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: AppText.headlineMd.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (c.formula.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primaryFixed, borderRadius: BorderRadius.circular(4)),
                  child: Text(Fmt.formula(c.formula),
                      style: AppText.monoMd
                          .copyWith(color: AppColors.onPrimaryFixed, fontWeight: FontWeight.w700)),
                ),
              if ((c.casNumber ?? '').isNotEmpty)
                Text('CAS: ${c.casNumber}',
                    style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
              if ((c.grade ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(4)),
                  child: Text(c.grade!,
                      style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
                ),
            ]),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, box) {
              final tiles = [_available(c), _minimum(c), _lastEntry(c)];
              if (box.maxWidth < 360) {
                return Column(children: [
                  for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: 6), child: t),
                ]);
              }
              return IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(child: tiles[i]),
                  ],
                ]),
              );
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _tile(Widget child) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(8)),
        child: child,
      );

  Widget _label(String s, IconData icon, {Color color = AppColors.outline}) => Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(s.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: AppText.monoSm.copyWith(color: color, fontWeight: FontWeight.w700)),
        ),
      ]);

  Widget _available(ChemicalModel c) {
    final cap = c.capacity;
    final color = switch (c.status) {
      StockStatus.normal => AppColors.primary,
      StockStatus.low => AppColors.warnFg,
      StockStatus.depleted => AppColors.critFg,
    };
    return _tile(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Available', Icons.water_drop_outlined, color: color),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(Fmt.qty(c.currentStock),
                style: AppText.headlineLg.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 4),
        Text(c.unit, style: AppText.monoMd.copyWith(color: AppColors.onSurfaceVariant)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: c.gaugeRatio,
          minHeight: 6,
          backgroundColor: AppColors.surfaceHigh,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        cap != null && cap > 0
            ? '${(c.currentStock / cap * 100).clamp(0, 100).toStringAsFixed(1)}% of ${Fmt.withUnit(cap, c.unit)} cap'
            : c.status == StockStatus.depleted
                ? 'Depleted'
                : c.status == StockStatus.low
                    ? 'Below minimum'
                    : 'In stock',
        style: AppText.monoSm.copyWith(color: AppColors.outline),
      ),
    ]));
  }

  Widget _minimum(ChemicalModel c) {
    final diff = c.currentStock - c.minimumStock;
    final ok = c.status == StockStatus.normal;
    return _tile(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Min Safe', Icons.flag_outlined),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(Fmt.qty(c.minimumStock), style: AppText.headlineLg.copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 4),
        Text(c.unit, style: AppText.monoMd.copyWith(color: AppColors.onSurfaceVariant)),
      ]),
      const SizedBox(height: 4),
      Pill(
        ok ? 'Optimal • +${Fmt.qty(diff)}' : 'Below • ${Fmt.qty(diff)}',
        bg: ok ? AppColors.okBg : AppColors.warnBg,
        fg: ok ? AppColors.okFg : AppColors.warnFg,
        radius: 4,
      ),
    ]));
  }

  Widget _lastEntry(ChemicalModel c) {
    final at = c.lastEntryAt ?? latest?.sortTime;
    return _tile(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Last Entry', Icons.schedule),
      const SizedBox(height: 4),
      if (at == null)
        Text('No entries', style: AppText.titleSm)
      else ...[
        Text(Fmt.day(at), style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700)),
        Text(Fmt.time(at), style: AppText.monoMd.copyWith(color: AppColors.primary)),
        if (latest != null)
          Text('By: ${latest!.createdByName.split(' ').last}',
              overflow: TextOverflow.ellipsis,
              style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
      ],
    ]));
  }
}
