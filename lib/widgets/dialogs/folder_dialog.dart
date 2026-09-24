import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../lab_inputs.dart';

/// Create ([existing] == null) or rename/edit a folder. Returns the new folder id on create.
Future<String?> showFolderDialog(BuildContext context, {CategoryModel? existing}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _FolderDialog(existing: existing),
    );

class _FolderDialog extends ConsumerStatefulWidget {
  const _FolderDialog({this.existing});
  final CategoryModel? existing;

  @override
  ConsumerState<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends ConsumerState<_FolderDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final _loc = TextEditingController(text: widget.existing?.location);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _loc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(categoryRepositoryProvider);
      String id;
      if (widget.existing == null) {
        id = await repo.create(
            name: _name.text, description: _desc.text, location: _loc.text, uid: user.uid);
      } else {
        id = widget.existing!.id;
        await repo.update(id, name: _name.text, description: _desc.text, location: _loc.text);
      }
      if (mounted) Navigator.pop(context, id);
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
    final editing = widget.existing != null;
    return AlertDialog(
      backgroundColor: AppColors.surfaceLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(children: [
        const Icon(Icons.create_new_folder_outlined, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(editing ? 'Edit folder' : 'New folder', style: AppText.headlineSm),
      ]),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              LabTextField(
                label: 'Folder name',
                controller: _name,
                required: true,
                autofocus: true,
                hint: 'e.g. Acids',
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a folder name' : null,
              ),
              const SizedBox(height: 12),
              LabTextField(
                  label: 'Description', controller: _desc, hint: 'What belongs in this folder?'),
              const SizedBox(height: 12),
              LabTextField(
                  label: 'Storage location',
                  controller: _loc,
                  hint: 'e.g. Cabinet A-04 • Corrosives Locker'),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppText.bodyMd.copyWith(color: AppColors.error)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(editing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
