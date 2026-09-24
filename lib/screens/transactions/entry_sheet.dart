import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/units.dart';
import '../../models/chemical_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/common_states.dart';
import '../../widgets/lab_inputs.dart';

/// Opens the Stitch "Record Usage / Receive Stock" sheet: bottom sheet on phones, dialog on
/// tablets and desktops.
Future<void> showEntrySheet(BuildContext context, ChemicalModel chemical,
    {TxType initial = TxType.stockOut}) {
  final content = EntrySheet(chemical: chemical, initialType: initial);
  if (!Responsive.isCompact(context)) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surfaceLowest,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 780), child: content),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceLowest,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => content,
  );
}

/// "Record Entry" FAB: pick a chemical first, then open the sheet.
Future<void> showChemicalPicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceLowest,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _ChemicalPicker(),
  );
}

class _ChemicalPicker extends ConsumerStatefulWidget {
  const _ChemicalPicker();
  @override
  ConsumerState<_ChemicalPicker> createState() => _ChemicalPickerState();
}

class _ChemicalPickerState extends ConsumerState<_ChemicalPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(chemicalsProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(99))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Expanded(child: Text('Which chemical?', style: AppText.headlineSm)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                  hintText: 'Search name or formula', prefixIcon: Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: AsyncBody<List<ChemicalModel>>(
              value: all,
              data: (list) {
                final f = list
                    .where((c) =>
                        _q.isEmpty ||
                        c.name.toLowerCase().contains(_q) ||
                        c.formula.toLowerCase().contains(_q))
                    .toList();
                if (f.isEmpty) {
                  return const EmptyState(icon: Icons.science_outlined, title: 'No chemicals found');
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: f.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = f[i];
                    return ListTile(
                      title: Text(c.name, style: AppText.titleSm),
                      subtitle: Text(
                          '${c.formula.isEmpty ? '' : '${Fmt.formula(c.formula)} • '}${Fmt.withUnit(c.currentStock, c.unit)} available',
                          style: AppText.monoSm),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        final nav = Navigator.of(context);
                        final root = nav.context;
                        nav.pop();
                        showEntrySheet(root, c);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class EntrySheet extends ConsumerStatefulWidget {
  const EntrySheet({super.key, required this.chemical, required this.initialType});
  final ChemicalModel chemical;
  final TxType initialType;

  @override
  ConsumerState<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<EntrySheet> {
  final _form = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _studentName = TextEditingController();
  final _studentId = TextEditingController();
  final _bench = TextEditingController();
  final _purpose = TextEditingController();
  final _supplier = TextEditingController();
  final _reference = TextEditingController();
  final _remarks = TextEditingController();

  late TxType _type = widget.initialType;
  late String _unit = widget.chemical.unit;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_qty, _studentName, _studentId, _bench, _purpose, _supplier, _reference, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isOut => _type == TxType.stockOut;

  Future<void> _submit(ChemicalModel chem) async {
    if (!_form.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = await ref.read(transactionRepositoryProvider).record(
            actor: user,
            chemicalId: chem.id,
            type: _type,
            quantity: parseDecimal(_qty.text)!,
            unit: _unit,
            date: _date,
            studentName: _studentName.text,
            studentId: _studentId.text,
            labBench: _bench.text,
            purpose: _purpose.text,
            supplier: _supplier.text,
            referenceNumber: _reference.text,
            remarks: _remarks.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text('${_isOut ? 'Usage' : 'Stock'} recorded. New balance: '
              '${Fmt.withUnit(entry.balanceAfter, entry.unit)}')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live stock so the "available" figure updates if another user changes it while this is open.
    final chem = ref.watch(chemicalProvider(widget.chemical.id)).valueOrNull ?? widget.chemical;
    final entered = parseDecimal(_qty.text);
    final converted = (entered == null || entered <= 0 || !Units.isCompatible(_unit, chem.unit))
        ? 0.0
        : Units.convert(entered, _unit, chem.unit);
    final after = Units.round(chem.currentStock + (_isOut ? -converted : converted));
    final exceeds = _isOut && converted > chem.currentStock + 1e-9;
    final units = Units.compatible(chem.unit);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(99))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(children: [
            const Icon(Icons.edit_note, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isOut ? 'Record Chemical Usage' : 'Add Stock', style: AppText.headlineSm),
                Text(
                    '${chem.name}${chem.formula.isEmpty ? '' : ' (${Fmt.formula(chem.formula)})'}',
                    overflow: TextOverflow.ellipsis,
                    style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
              ]),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _modeToggle(),
                const SizedBox(height: 12),
                _banner(chem, converted, after, exceeds),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    flex: 7,
                    child: LabTextField(
                      label: _isOut ? 'Quantity Used' : 'Quantity Received',
                      controller: _qty,
                      required: true,
                      mono: true,
                      hint: '0.0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalInputFormatters,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final n = parseDecimal(v);
                        if (n == null) return 'Enter a number';
                        if (n <= 0) return 'Must be greater than zero';
                        if (_isOut && exceeds) {
                          return 'Only ${Fmt.withUnit(chem.currentStock, chem.unit)} available';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: LabDropdown<String>(
                      label: 'Unit',
                      value: _unit,
                      items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u, style: AppText.monoMd))],
                      onChanged: (u) => setState(() => _unit = u ?? _unit),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                LabDateField(
                    label: 'Date', value: _date, required: true, onChanged: (d) => setState(() => _date = d)),
                const SizedBox(height: 16),
                if (_isOut) ..._usageFields() else ..._stockFields(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 18, color: AppColors.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: AppText.bodyMd.copyWith(color: AppColors.onErrorContainer))),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_saving || exceeds) ? null : () => _submit(chem),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified_outlined, size: 18),
                  label: Text(_isOut ? 'Commit Usage' : 'Add Stock'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _modeToggle() {
    Widget seg(String label, TxType t) {
      final sel = _type == t;
      return Expanded(
        child: GestureDetector(
          onTap: _saving ? null : () => setState(() => _type = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? AppColors.surfaceLowest : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: sel
                  ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]
                  : null,
            ),
            child: Text(label,
                style: AppText.titleSm.copyWith(color: sel ? AppColors.primary : AppColors.onSurfaceVariant)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [seg('Record Usage (-)', TxType.stockOut), seg('Receive Stock (+)', TxType.stockIn)]),
    );
  }

  Widget _banner(ChemicalModel chem, double converted, double after, bool exceeds) {
    final labels = _isOut
        ? ('Available Before', 'Used', 'Remaining')
        : ('Previous Available', 'Quantity Added', 'New Available');
    Widget cell(String l, String v, Color c, {bool tint = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: tint ? AppColors.tertiaryFixed.withValues(alpha: 0.3) : null,
                borderRadius: BorderRadius.circular(6)),
            child: Column(children: [
              Text(l, textAlign: TextAlign.center, style: AppText.bodySm.copyWith(color: c)),
              const SizedBox(height: 2),
              Text(v, style: AppText.monoMd.copyWith(color: c, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    final bad = exceeds;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.calculate_outlined, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Expanded(
              child: Text('LIVE BALANCE COMPUTATION',
                  style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.8))),
          Pill(bad ? 'Exceeds stock' : 'Valid',
              bg: bad ? AppColors.critBg : AppColors.tertiaryFixed,
              fg: bad ? AppColors.critFg : AppColors.onTertiaryFixed,
              icon: bad ? Icons.block : Icons.verified_outlined,
              radius: 4),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.surfaceLowest, borderRadius: BorderRadius.circular(8)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            cell(labels.$1, Fmt.withUnit(chem.currentStock, chem.unit), AppColors.onSurface),
            cell(labels.$2, converted == 0 ? '—' : Fmt.signed(converted, chem.unit, negative: _isOut),
                _isOut ? AppColors.error : AppColors.tertiary),
            cell(labels.$3, Fmt.withUnit(bad ? chem.currentStock : after, chem.unit),
                bad ? AppColors.critFg : AppColors.tertiary, tint: true),
          ]),
        ),
        if (_isOut) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.shield_outlined, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  'Usage cannot exceed the registered stock (${Fmt.withUnit(chem.currentStock, chem.unit)}).',
                  style: AppText.bodySm.copyWith(color: AppColors.outline)),
            ),
          ]),
        ],
      ]),
    );
  }

  List<Widget> _usageFields() => [
        Text('Student / Recipient', style: AppText.titleSm),
        const SizedBox(height: 8),
        LabTextField(
          label: 'Student Full Name',
          controller: _studentName,
          required: true,
          textInputAction: TextInputAction.next,
          validator: (v) => (v ?? '').trim().isEmpty ? 'Student name is required' : null,
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: LabTextField(label: 'Student ID / Roll', controller: _studentId, mono: true)),
          const SizedBox(width: 12),
          Expanded(child: LabTextField(label: 'Lab Station / Bench', controller: _bench, mono: true)),
        ]),
        const SizedBox(height: 16),
        Text('Experimental Context', style: AppText.titleSm),
        const SizedBox(height: 8),
        LabTextField(
          label: 'Purpose / Experiment',
          controller: _purpose,
          required: true,
          validator: (v) => (v ?? '').trim().isEmpty ? 'Purpose is required' : null,
        ),
        const SizedBox(height: 12),
        LabTextField(label: 'Remarks', controller: _remarks, maxLines: 2),
      ];

  List<Widget> _stockFields() => [
        LabTextField(label: 'Supplier / Source', controller: _supplier, hint: 'e.g. Sigma-Aldrich'),
        const SizedBox(height: 12),
        LabTextField(label: 'Reference / Invoice number', controller: _reference, mono: true),
        const SizedBox(height: 12),
        LabTextField(label: 'Notes', controller: _remarks, maxLines: 2),
      ];
}
