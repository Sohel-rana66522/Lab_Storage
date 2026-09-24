import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/units.dart';
import '../../models/category_model.dart';
import '../../models/chemical_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../widgets/common_states.dart';
import '../../widgets/lab_inputs.dart';

/// Create a chemical file (with optional opening balance), or edit its metadata.
/// The unit and stock cannot be changed here once created — stock only ever moves through
/// Add Stock / Record Usage, so history always adds up.
class ChemicalFormScreen extends ConsumerStatefulWidget {
  const ChemicalFormScreen({super.key, this.chemicalId, this.categoryId});
  final String? chemicalId;
  final String? categoryId;

  bool get isEdit => chemicalId != null;

  @override
  ConsumerState<ChemicalFormScreen> createState() => _ChemicalFormScreenState();
}

class _ChemicalFormScreenState extends ConsumerState<ChemicalFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _formula = TextEditingController();
  final _cas = TextEditingController();
  final _grade = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  final _minimum = TextEditingController(text: '0');
  final _capacity = TextEditingController();
  final _initialStock = TextEditingController(text: '0');

  String? _categoryId;
  String _unit = 'L';
  String? _hazard;
  bool _saving = false;
  bool _hydrated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _formula,
      _cas,
      _grade,
      _location,
      _description,
      _notes,
      _minimum,
      _capacity,
      _initialStock,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(ChemicalModel c) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = c.name;
    _formula.text = c.formula;
    _cas.text = c.casNumber ?? '';
    _grade.text = c.grade ?? '';
    _location.text = c.location ?? '';
    _description.text = c.description ?? '';
    _notes.text = c.notes ?? '';
    _minimum.text = Fmt.qty(c.minimumStock);
    _capacity.text = c.capacity == null ? '' : Fmt.qty(c.capacity!);
    _categoryId = c.categoryId;
    _unit = c.unit;
    _hazard = c.hazardClass;
  }

  Future<void> _save({ChemicalModel? existing}) async {
    if (!_form.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (_categoryId == null) {
      setState(() => _error = 'Choose a folder for this chemical.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = ChemicalModel(
      id: existing?.id ?? '',
      name: _name.text.trim(),
      formula: _formula.text.trim(),
      categoryId: _categoryId!,
      unit: _unit,
      minimumStock: parseDecimal(_minimum.text) ?? 0,
      capacity: parseDecimal(_capacity.text),
      description: _description.text.trim(),
      notes: _notes.text.trim(),
      casNumber: _cas.text.trim(),
      grade: _grade.text.trim(),
      location: _location.text.trim(),
      hazardClass: _hazard,
    );

    try {
      if (existing == null) {
        final id = await ref.read(chemicalRepositoryProvider).create(
              draft: draft,
              initialStock: parseDecimal(_initialStock.text) ?? 0,
              date: DateTime.now(),
              actor: user,
            );
        if (mounted) context.pushReplacement('/chemicals/$id');
      } else {
        await ref.read(chemicalRepositoryProvider).update(draft.copyWith(id: existing.id));
        if (mounted) context.pop();
      }
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
    final categories = ref.watch(categoriesProvider);
    final existingAsync = widget.isEdit ? ref.watch(chemicalProvider(widget.chemicalId!)) : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(widget.isEdit ? 'Edit Chemical' : 'New Chemical File', style: AppText.titleMd),
      ),
      body: SafeArea(
        child: widget.isEdit
            ? AsyncBody<ChemicalModel?>(
                value: existingAsync!,
                data: (c) {
                  if (c == null) {
                    return const EmptyState(icon: Icons.folder_off_outlined, title: 'Chemical not found');
                  }
                  _hydrate(c);
                  return _formBody(categories, existing: c);
                },
              )
            : _formBody(categories, existing: null),
      ),
    );
  }

  Widget _formBody(AsyncValue<List<CategoryModel>> categories, {ChemicalModel? existing}) {
    final cats = categories.valueOrNull ?? const <CategoryModel>[];
    return PageContainer(
      maxWidth: 720,
      child: Form(
        key: _form,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('Chemical Information', style: AppText.titleMd),
          const SizedBox(height: 12),
          LabTextField(
              label: 'Chemical name',
              controller: _name,
              required: true,
              hint: 'e.g. Hydrochloric Acid',
              validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required' : null),
          const SizedBox(height: 12),
          LabTextField(
              label: 'Formula',
              controller: _formula,
              mono: true,
              hint: 'e.g. HCl or H2SO4 (digits become subscripts)'),
          const SizedBox(height: 12),
          LabDropdown<String>(
            label: 'Folder',
            value: cats.any((c) => c.id == _categoryId) ? _categoryId : null,
            hint: cats.isEmpty ? 'No folders yet' : 'Choose a folder',
            required: true,
            items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: LabTextField(label: 'CAS number', controller: _cas, mono: true)),
            const SizedBox(width: 12),
            Expanded(child: LabTextField(label: 'Grade', controller: _grade, hint: 'e.g. ACS Reagent')),
          ]),
          const SizedBox(height: 12),
          LabDropdown<String>(
            label: 'Hazard class',
            value: _hazard,
            hint: 'None specified',
            items: [for (final h in hazardClasses) DropdownMenuItem(value: h, child: Text(h))],
            onChanged: (v) => setState(() => _hazard = v),
          ),
          const SizedBox(height: 12),
          LabTextField(label: 'Storage location', controller: _location, hint: 'e.g. Room 3B / Cab 02'),
          const SizedBox(height: 12),
          LabTextField(label: 'Description', controller: _description, maxLines: 2),
          const SizedBox(height: 12),
          LabTextField(label: 'Handling notes', controller: _notes, maxLines: 2),

          const SizedBox(height: 24),
          Text('Stock & Unit', style: AppText.titleMd),
          const SizedBox(height: 4),
          Text(
              existing == null
                  ? 'The unit is fixed once the chemical is created.'
                  : 'The unit and current stock cannot be changed here — use Add Stock / Record Usage.',
              style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 7,
              child: existing == null
                  ? LabTextField(
                      label: 'Initial stock',
                      controller: _initialStock,
                      mono: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalInputFormatters,
                      validator: (v) {
                        final n = parseDecimal(v);
                        if (n == null) return 'Enter a number';
                        if (n < 0) return 'Cannot be negative';
                        return null;
                      },
                    )
                  : IgnorePointer(
                      child: Opacity(
                        opacity: 0.6,
                        child: LabTextField(
                            label: 'Current stock',
                            controller: TextEditingController(text: Fmt.qty(existing.currentStock)),
                            mono: true,
                            enabled: false),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: existing == null
                  ? LabDropdown<String>(
                      label: 'Unit',
                      value: _unit,
                      items: [for (final u in Units.all) DropdownMenuItem(value: u, child: Text(u, style: AppText.monoMd))],
                      onChanged: (u) => setState(() => _unit = u ?? _unit),
                    )
                  : IgnorePointer(
                      child: Opacity(
                        opacity: 0.6,
                        child: LabTextField(
                            label: 'Unit',
                            controller: TextEditingController(text: existing.unit),
                            mono: true,
                            enabled: false),
                      ),
                    ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: LabTextField(
                label: 'Minimum safe stock',
                controller: _minimum,
                mono: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimalInputFormatters,
                helper: 'Marks this chemical Low Stock at or below this level.',
                validator: (v) {
                  final n = parseDecimal(v);
                  if (n == null) return 'Enter a number';
                  if (n < 0) return 'Cannot be negative';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LabTextField(
                label: 'Bottle / cabinet capacity',
                controller: _capacity,
                mono: true,
                hint: 'Optional',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimalInputFormatters,
              ),
            ),
          ]),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: AppText.bodyMd.copyWith(color: AppColors.onErrorContainer)),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : () => _save(existing: existing),
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(existing == null ? 'Create Chemical File' : 'Save changes'),
          ),
        ],
      ),
      ),
    );
  }
}
