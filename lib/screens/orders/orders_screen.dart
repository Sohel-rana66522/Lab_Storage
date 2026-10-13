import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../client/models/order_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/order_admin_provider.dart';
import '../../widgets/common_states.dart';
import '../../widgets/order_status_pill.dart';

/// Client orders waiting for, or already given, a decision. Orders arrive live: a request
/// submitted from the Client Portal appears under Pending without a refresh.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _status = OrderStatus.pending;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);

    return PageContainer(
      maxWidth: 760,
      child: AsyncBody<List<OrderModel>>(
        value: orders,
        onRetry: () => ref.invalidate(ordersProvider),
        data: (all) {
          final counts = {
            for (final s in OrderStatus.all) s: all.where((o) => o.status == s).length,
          };
          final shown = all.where((o) => o.status == _status).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in OrderStatus.all)
                  ChoiceChip(
                    label: Text('$s (${counts[s]})'),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                    selectedColor: AppColors.primaryFixed,
                    labelStyle: AppText.titleSm.copyWith(
                        color: _status == s ? AppColors.onPrimaryFixed : AppColors.onSurfaceVariant),
                  ),
              ]),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No ${_status.toLowerCase()} orders',
                  message: _status == OrderStatus.pending
                      ? 'New requests from the Client Portal will appear here.'
                      : null,
                )
              else
                for (final o in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OrderCard(order: o, onTap: () => context.push('/orders/${o.id}')),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final OrderModel order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final when = o.createdAt == null ? 'Just now' : Fmt.dateTime(o.createdAt!);
    final n = o.items.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: AppDeco.card(),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(o.id,
                    style: AppText.monoLg.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              OrderStatusPill(o.status),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Flexible(
                  child: Text(o.clientName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleMd)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                    color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(4)),
                child: Text(o.clientId, style: AppText.monoSm.copyWith(color: AppColors.outline)),
              ),
            ]),
            const SizedBox(height: 2),
            Text('Batch: ${o.clientBatch} · ${o.clientPhone}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.science_outlined, size: 14, color: AppColors.outline),
              const SizedBox(width: 4),
              Text('$n chemical${n == 1 ? '' : 's'}',
                  style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              const Spacer(),
              Text(when, style: AppText.monoSm.copyWith(color: AppColors.outline)),
            ]),
          ]),
        ),
      ),
    );
  }
}
