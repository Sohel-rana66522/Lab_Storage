import 'package:flutter/material.dart';

import '../client/models/order_model.dart';
import '../core/theme/app_colors.dart';
import 'common_states.dart';

/// Pending / Approved / Rejected, in the same tints the stock chips use.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case OrderStatus.approved:
        return const Pill('Approved',
            bg: AppColors.okBg, fg: AppColors.okFg, icon: Icons.check_circle_outline);
      case OrderStatus.rejected:
        return const Pill('Rejected',
            bg: AppColors.critBg, fg: AppColors.critFg, icon: Icons.cancel_outlined);
      default:
        return const Pill('Pending',
            bg: AppColors.warnBg, fg: AppColors.warnFg, icon: Icons.hourglass_empty);
    }
  }
}
