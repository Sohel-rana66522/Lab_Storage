import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../core/theme/app_theme.dart';
import '../models/transaction_model.dart';
import 'common_states.dart';

/// One line of recent activity: "Sohel Rana • Deducted 500 mL • Hydrochloric Acid (HCl)".
class LedgerTile extends StatelessWidget {
  const LedgerTile({super.key, required this.entry, this.onTap, this.showDate = false});
  final TransactionModel entry;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final t = entry;
    final title = t.isIn
        ? (t.isInitial ? 'Initial stock' : 'Stock received')
        : (t.studentName ?? 'Usage recorded');
    final formula = t.chemicalFormula.isEmpty ? '' : ' (${Fmt.formula(t.chemicalFormula)})';
    final action = t.isIn ? 'Received' : 'Deducted';
    final when = t.sortTime;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          t.isIn
              ? const InitialsBadge('+', bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixed)
              : InitialsBadge(Fmt.initials(t.studentName)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleSm)),
                if (!t.isIn && (t.studentId ?? '').isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                        color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(4)),
                    child: Text(t.studentId!, style: AppText.monoSm.copyWith(color: AppColors.outline)),
                  ),
                ],
              ]),
              Text('$action ${Fmt.withUnit(t.quantity, t.unit)} • ${t.chemicalName}$formula',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              Text('Recorded by ${t.createdByName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.monoSm.copyWith(color: AppColors.outline)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.signed(t.quantity, t.unit, negative: !t.isIn),
                style: AppText.monoMd.copyWith(
                    color: t.isIn ? AppColors.tertiary : AppColors.error, fontWeight: FontWeight.w700)),
            Text(showDate ? Fmt.dateTime(when) : Fmt.time(when),
                style: AppText.monoSm.copyWith(color: AppColors.outline)),
          ]),
        ]),
      ),
    );
  }
}
