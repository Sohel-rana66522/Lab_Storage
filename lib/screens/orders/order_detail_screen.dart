import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../client/models/order_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/units.dart';
import '../../models/chemical_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../providers/order_admin_provider.dart';
import '../../widgets/common_states.dart';
import '../../widgets/dialogs/confirm_dialog.dart';
import '../../widgets/lab_inputs.dart';
import '../../widgets/order_status_pill.dart';

/// One order in full, with Approve / Reject. Stock figures are LIVE, so the admin sees
/// exactly what the approval will be validated against.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;
  String? _error;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _approve(OrderModel order) async {
    if (_busy) return; // a second tap while the first is running does nothing
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final n = order.items.length;
    final ok = await confirmDialog(
      context,
      title: 'Approve order?',
      message: 'This issues $n chemical${n == 1 ? '' : 's'} to ${order.clientName} and deducts '
          '${n == 1 ? 'it' : 'them'} from stock straight away. It cannot be undone.',
      confirmLabel: 'Approve order',
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(orderAdminRepositoryProvider)
          .approve(actor: user, orderId: order.id);
      // Reached only when the whole approval is confirmed.
      if (outcome.alreadyApproved) {
        _toast('This order was already approved. No stock was changed.');
      } else if (outcome.confirmedAfterError) {
        _toast('The connection dropped, but the approval did complete. Stock is updated.');
      } else {
        _toast('Order approved. $n chemical${n == 1 ? '' : 's'} issued and stock updated.');
      }
    } catch (e, st) {
      developer.log('approve failed', name: 'OrderDetailScreen', error: e, stackTrace: st);
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(OrderModel order) async {
    if (_busy) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final reasonC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Reject order?', style: AppText.headlineSm),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${order.clientName} will see this order as Rejected. No stock is deducted.',
                style: AppText.bodyMd),
            const SizedBox(height: 12),
            LabTextField(
              label: 'Reason (optional)',
              controller: reasonC,
              maxLines: 3,
              hint: 'e.g. Supervisor approval missing',
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.critBg, foregroundColor: AppColors.critFg),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject order'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final changed = await ref
          .read(orderAdminRepositoryProvider)
          .reject(actor: user, orderId: order.id, reason: reasonC.text);
      _toast(changed ? 'Order rejected. No stock was changed.' : 'This order was already rejected.');
    } catch (e, st) {
      developer.log('reject failed', name: 'OrderDetailScreen', error: e, stackTrace: st);
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.orderId));
    final chemicals = ref.watch(chemicalsProvider).valueOrNull ?? const <ChemicalModel>[];
    final byId = {for (final c in chemicals) c.id: c};
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/orders'),
        ),
        title: Text('Order ${widget.orderId}',
            overflow: TextOverflow.ellipsis, style: AppText.titleMd),
      ),
      body: SafeArea(
        child: AsyncBody<OrderModel?>(
          value: orderAsync,
          data: (order) {
            if (order == null) {
              return EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Order not found',
                message: 'It may have been removed.',
                actionLabel: 'Back to Orders',
                onAction: () => context.go('/orders'),
              );
            }
            final lines = [
              for (final item in order.items) _Line.build(item, byId[item.chemicalId]),
            ];
            final problems = [for (final l in lines) if (l.problem != null) '${l.item.chemicalName}: ${l.problem}'];

            return PageContainer(
              maxWidth: 760,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                _Header(order: order),
                const SizedBox(height: 12),
                for (final l in lines) ...[
                  _ItemCard(line: l),
                  const SizedBox(height: 8),
                ],
                if (order.isPending && problems.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _Banner(
                    color: AppColors.warnBg,
                    fg: AppColors.warnFg,
                    icon: Icons.warning_amber_rounded,
                    text: 'Approval would currently fail:\n${problems.join('\n')}',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  _Banner(
                    color: AppColors.critBg,
                    fg: AppColors.critFg,
                    icon: Icons.error_outline,
                    text: _error!,
                  ),
                ],
                const SizedBox(height: 16),
                if (order.isPending)
                  isAdmin
                      ? Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : () => _reject(order),
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.critFg),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject Order'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : () => _approve(order),
                              icon: _busy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check, size: 18),
                              label: Text(_busy ? 'Working…' : 'Approve Order'),
                            ),
                          ),
                        ])
                      : const _Banner(
                          color: AppColors.surfaceContainer,
                          fg: AppColors.onSurfaceVariant,
                          icon: Icons.lock_outline,
                          text: 'Only laboratory admins can approve or reject orders. '
                              'Your account does not have the ADMIN role.',
                        ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// One order item joined with the chemical's live stock.
class _Line {
  _Line(this.item, this.chem, this.problem);
  final OrderItem item;
  final ChemicalModel? chem;

  /// Why this item cannot be issued right now, or null.
  final String? problem;

  static _Line build(OrderItem item, ChemicalModel? chem) {
    if (chem == null) return _Line(item, null, 'chemical not found in the archive');
    if (!Units.isCompatible(item.unit, chem.unit)) {
      return _Line(item, chem, '${item.unit} is not compatible with ${chem.unit}');
    }
    if (!item.requestedQuantity.isFinite || item.requestedQuantity <= 0) {
      return _Line(item, chem, 'invalid quantity');
    }
    final need = Units.convert(item.requestedQuantity, item.unit, chem.unit);
    if (need > chem.currentStock + 1e-9) {
      return _Line(item, chem, 'needs ${Fmt.withUnit(need, chem.unit)} but only '
          '${Fmt.withUnit(chem.currentStock, chem.unit)} is in stock');
    }
    return _Line(item, chem, null);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    Widget row(String label, String value, {bool mono = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant))),
            Expanded(child: SelectableText(value, style: mono ? AppText.monoMd : AppText.bodyMd)),
          ]),
        );

    return Container(
      decoration: AppDeco.card(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(o.id, style: AppText.monoLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700))),
          OrderStatusPill(o.status),
        ]),
        const SizedBox(height: 8),
        row('Client name', o.clientName),
        row('Client ID', o.clientId, mono: true),
        row('Batch', o.clientBatch),
        row('Phone', o.clientPhone, mono: true),
        row('Submitted at', o.createdAt == null ? 'Just now' : Fmt.dateTime(o.createdAt!)),
        if (o.isApproved && o.approvedAt != null)
          row('Approved', '${Fmt.dateTime(o.approvedAt!)}${(o.approvedByName ?? '').isEmpty ? '' : ' by ${o.approvedByName}'}'),
        if (o.isRejected && o.rejectedAt != null)
          row('Rejected', '${Fmt.dateTime(o.rejectedAt!)}${(o.rejectedByName ?? '').isEmpty ? '' : ' by ${o.rejectedByName}'}'),
        if (o.isRejected && (o.rejectionReason ?? '').isNotEmpty) row('Reason', o.rejectionReason!),
      ]),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.line});
  final _Line line;

  @override
  Widget build(BuildContext context) {
    final item = line.item;
    final chem = line.chem;
    final short = line.problem != null;
    final formula = item.formula.isEmpty ? '' : ' (${Fmt.formula(item.formula)})';

    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.6)),
            const SizedBox(height: 2),
            Text(value, style: AppText.monoMd.copyWith(color: color, fontWeight: FontWeight.w600)),
          ]),
        );

    return Container(
      decoration: AppDeco.card(),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('${item.chemicalName}$formula',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.titleMd)),
          if (short) const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warnFg),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          cell('Requested', Fmt.withUnit(item.requestedQuantity, item.unit)),
          cell('Unit', item.unit),
          cell('Available stock',
              chem == null ? 'N/A' : Fmt.withUnit(chem.currentStock, chem.unit),
              color: short ? AppColors.critFg : null),
        ]),
        if (short) ...[
          const SizedBox(height: 8),
          Text(line.problem![0].toUpperCase() + line.problem!.substring(1),
              style: AppText.bodySm.copyWith(color: AppColors.critFg)),
        ],
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.fg, required this.icon, required this.text});
  final Color color;
  final Color fg;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.bodyMd.copyWith(color: fg))),
        ]),
      );
}
