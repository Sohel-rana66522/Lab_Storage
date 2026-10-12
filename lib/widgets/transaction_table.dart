import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_model.dart';

/// The digital entry-book page. Wide screens show the full table
/// (Date | Student | Batch | Supervisor | Added | Used | Balance); phones use the compact
/// three-column ledger row from the Stitch design.
class TransactionTable extends StatelessWidget {
  const TransactionTable({super.key, required this.entries});
  final List<TransactionModel> entries;

  /// Batch recorded on a usage entry ("Batch: X" is stored in `purpose`), or '' if none.
  static String batchOf(TransactionModel t) {
    if (t.isIn) return '';
    final p = (t.purpose ?? '').trim();
    return p.startsWith('Batch:') ? p.substring(6).trim() : '';
  }

  /// Supervisor recorded on a usage entry ("Supervisor: X" is stored in `remarks`), or ''.
  static String supervisorOf(TransactionModel t) {
    if (t.isIn) return '';
    final r = (t.remarks ?? '').trim();
    return r.startsWith('Supervisor:') ? r.substring(11).trim() : '';
  }

  static String _dash(String s) => s.isEmpty ? '—' : s;

  static String _title(TransactionModel t) {
    if (t.isIn) return t.isInitial ? 'Initial Stock' : 'Stock received';
    return t.studentName ?? 'Usage';
  }

  static String _subtitle(TransactionModel t) {
    if (t.isIn) {
      final parts = [t.supplier, t.referenceNumber, t.remarks == 'Initial stock' ? null : t.remarks]
          .whereType<String>()
          .where((s) => s.isNotEmpty);
      return parts.isEmpty ? '—' : parts.join(', ');
    }
    final id = (t.studentId ?? '').trim();
    return id.isEmpty ? '—' : 'ID: $id';
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 640 ? _wide() : _compact(),
      );

  Widget _wide() {
    const head = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8);
    Widget h(String s, {double? w, int flex = 0, TextAlign align = TextAlign.left}) {
      final t = Text(s.toUpperCase(),
          textAlign: align, style: AppText.monoSm.merge(head).copyWith(color: AppColors.onSurfaceVariant));
      return w != null ? SizedBox(width: w, child: t) : Expanded(flex: flex, child: t);
    }

    return Column(children: [
      Container(
        color: AppColors.surfaceContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          h('Date', w: 110),
          h('Student', flex: 3),
          h('Batch', w: 90),
          h('Supervisor', w: 130),
          h('Added', w: 90, align: TextAlign.right),
          h('Used', w: 90, align: TextAlign.right),
          h('Balance', w: 100, align: TextAlign.right),
        ]),
      ),
      for (var i = 0; i < entries.length; i++) _wideRow(entries[i], i),
    ]);
  }

  Widget _wideRow(TransactionModel t, int i) {
    final mono = AppText.monoMd;
    return Container(
      color: i.isOdd ? AppColors.surfaceLow : AppColors.surfaceLowest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        SizedBox(width: 110, child: Text(Fmt.date(t.date), style: mono.copyWith(fontWeight: FontWeight.w600))),
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title(t),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.titleSm.copyWith(color: t.isIn ? AppColors.tertiary : AppColors.onSurface)),
            Text(_subtitle(t),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          ]),
        ),
        SizedBox(
            width: 90,
            child: Text(_dash(batchOf(t)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant))),
        SizedBox(
            width: 130,
            child: Text(_dash(supervisorOf(t)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant))),
        SizedBox(
            width: 90,
            child: Text(t.isIn ? Fmt.withUnit(t.quantity, t.unit) : '—',
                textAlign: TextAlign.right,
                style: mono.copyWith(color: AppColors.tertiary, fontWeight: FontWeight.w700))),
        SizedBox(
            width: 90,
            child: Text(t.isIn ? '—' : Fmt.withUnit(t.quantity, t.unit),
                textAlign: TextAlign.right,
                style: mono.copyWith(color: AppColors.error, fontWeight: FontWeight.w700))),
        SizedBox(
            width: 100,
            child: Text(Fmt.withUnit(t.balanceAfter, t.unit),
                textAlign: TextAlign.right,
                style: mono.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _compact() => Column(children: [
        Container(
          color: AppColors.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            SizedBox(width: 92, child: _h('Date / Batch')),
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _h('Student & Supervisor'))),
            SizedBox(width: 92, child: _h('Flow & Balance', right: true)),
          ]),
        ),
        for (var i = 0; i < entries.length; i++) _compactRow(entries[i], i),
      ]);

  Widget _h(String s, {bool right = false}) => Text(s.toUpperCase(),
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: AppText.monoSm.copyWith(
          color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700, letterSpacing: 0.8));

  Widget _compactRow(TransactionModel t, int i) {
    final flow = Fmt.signed(t.quantity, t.unit, negative: !t.isIn);
    final batch = batchOf(t);
    final supervisor = supervisorOf(t);
    return Container(
      color: i.isOdd ? AppColors.surfaceLow : AppColors.surfaceLowest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 92,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Fmt.date(t.date), style: AppText.monoMd.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(_dash(batch),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoSm.copyWith(color: AppColors.outline)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (t.isIn) ...[
                  const Icon(Icons.local_shipping_outlined, size: 14, color: AppColors.tertiary),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(_title(t),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.titleSm.copyWith(color: t.isIn ? AppColors.tertiary : AppColors.onSurface)),
                ),
              ]),
              Text(t.isIn ? _subtitle(t) : (supervisor.isEmpty ? _subtitle(t) : 'Sup: $supervisor'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            ]),
          ),
        ),
        SizedBox(
          width: 92,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(flow,
                style: AppText.monoMd.copyWith(
                    color: t.isIn ? AppColors.tertiary : AppColors.error, fontWeight: FontWeight.w700)),
            Text('Bal: ${Fmt.withUnit(t.balanceAfter, t.unit)}',
                style: AppText.monoSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}