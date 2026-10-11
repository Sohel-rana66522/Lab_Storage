import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/common_states.dart';
import '../../widgets/order_status_pill.dart';
import '../models/cart_line.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../utils/client_errors.dart';
import '../widgets/client_ui.dart';

/// The orders this visitor has placed, with live status. Read-only: nothing here can change
/// an order, and the security rules would refuse it anyway.
class ClientMyOrdersPage extends ConsumerWidget {
  const ClientMyOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);

    return PageContainer(
      maxWidth: 760,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Row(children: [
          SquareIconButton(
              icon: Icons.arrow_back, tooltip: 'Back', onTap: () => popOrGo(context, '/')),
          const SizedBox(width: 8),
          Text('My Orders', style: AppText.headlineSm),
        ]),
        const SizedBox(height: 12),
        orders.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: clientErrorMessage(e),
            onRetry: () => ref.invalidate(myOrdersProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders yet',
                message: 'Orders you submit from this device appear here with their status.',
                actionLabel: 'Browse chemicals',
                onAction: () => context.go('/'),
              );
            }
            return Column(children: [
              for (final o in list)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: _MyOrderCard(order: o)),
            ]);
          },
        ),
      ]),
    );
  }
}

class _MyOrderCard extends StatelessWidget {
  const _MyOrderCard({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final when = o.createdAt == null ? 'Just now' : Fmt.dateTime(o.createdAt!);

    String? note;
    Color noteFg = AppColors.onSurfaceVariant;
    if (o.isPending) {
      note = 'Waiting for the laboratory to review this request.';
    } else if (o.isApproved) {
      note = 'Approved. Please collect your chemicals from the laboratory.';
      noteFg = AppColors.okFg;
    } else if (o.isRejected) {
      final reason = (o.rejectionReason ?? '').trim();
      note = reason.isEmpty ? 'This request was rejected.' : 'Rejected: $reason';
      noteFg = AppColors.critFg;
    }

    return Container(
      decoration: AppDeco.card(),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: SelectableText(o.id,
                style: AppText.monoLg.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          OrderStatusPill(o.status),
        ]),
        const SizedBox(height: 2),
        Text('Submitted $when',
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 10),
        for (final item in o.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(
                child: Text(
                    '${item.chemicalName}'
                    '${item.formula.isEmpty ? '' : ' (${Fmt.formula(item.formula)})'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMd),
              ),
              const SizedBox(width: 8),
              Text(CartRules.withUnit(item.requestedQuantity, item.unit),
                  style: AppText.monoMd.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note, style: AppText.bodySm.copyWith(color: noteFg)),
        ],
      ]),
    );
  }
}
