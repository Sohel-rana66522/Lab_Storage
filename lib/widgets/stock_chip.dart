import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/chemical_model.dart';
import 'common_states.dart';

/// Stock status chip: In Stock / Low Stock / Depleted (DESIGN.md "Stock Status Chips").
class StockChip extends StatelessWidget {
  const StockChip(this.status, {super.key});
  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case StockStatus.normal:
        return const Pill('In Stock',
            bg: AppColors.okBg, fg: AppColors.okFg, radius: 4);
      case StockStatus.low:
        return const Pill('Low Stock',
            bg: AppColors.warnBg, fg: AppColors.warnFg, icon: Icons.warning_amber_rounded, radius: 4);
      case StockStatus.depleted:
        return const Pill('Depleted',
            bg: AppColors.critBg, fg: AppColors.critFg, icon: Icons.block, radius: 4);
    }
  }
}

Color statusColor(StockStatus s) => switch (s) {
      StockStatus.normal => AppColors.primary,
      StockStatus.low => AppColors.warnFg,
      StockStatus.depleted => AppColors.critFg,
    };
