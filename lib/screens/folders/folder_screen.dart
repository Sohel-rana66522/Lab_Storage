import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/csv.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/category_model.dart';
import '../../models/chemical_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../providers/ui_providers.dart';
import '../../widgets/common_states.dart';
import '../../widgets/dialogs/confirm_dialog.dart';
import '../../widgets/dialogs/folder_dialog.dart';
import '../../widgets/file_card.dart';

/// Inside one folder: its chemical "files".
class FolderScreen extends ConsumerStatefulWidget {
  const FolderScreen({super.key, required this.categoryId});
  final String categoryId;

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _delete(CategoryModel cat) async {
    final ok = await confirmDialog(context,
        title: 'Delete "${cat.name}"?',
        message: 'The folder will be removed. Folders that still contain chemicals cannot be deleted.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok || !mounted) return;
    try {
      await ref.read(categoryRepositoryProvider).delete(cat.id);
      if (mounted) context.go('/folders');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    final chemsAsync = ref.watch(chemicalsProvider);

    return PageContainer(
      child: AsyncBody<List<CategoryModel>>(
        value: catsAsync,
        data: (cats) {
          final cat = cats.where((c) => c.id == widget.categoryId).firstOrNull;
          if (cat == null) {
            return EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'Folder not found',
              message: 'It may have been deleted.',
              actionLabel: 'Back to folders',
              onAction: () => context.go('/folders'),
            );
          }
          return AsyncBody<List<ChemicalModel>>(
            value: chemsAsync,
            data: (all) => _content(cat, all.where((c) => c.categoryId == cat.id).toList()),
          );
        },
      ),
    );
  }

  Widget _content(CategoryModel cat, List<ChemicalModel> inFolder) {
    final sort = ref.watch(chemSortProvider);
    final grid = ref.watch(chemGridProvider);
    final q = _filter.text.trim().toLowerCase();
    final shown = inFolder
        .where((c) =>
            q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.formula.toLowerCase().contains(q) ||
            (c.casNumber ?? '').toLowerCase().contains(q) ||
            (c.location ?? '').toLowerCase().contains(q) ||
            (c.grade ?? '').toLowerCase().contains(q))
        .toList()
      ..sort(sort.compare);
    final lowCount = inFolder.where((c) => c.isLow).length;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      // Breadcrumb
      Row(children: [
        _squareBtn(Icons.arrow_back, () => context.go('/folders'), 'Back to all folders'),
        const SizedBox(width: 8),
        Expanded(
          child: Row(children: [
            Text('Ledger Archive', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.outline),
            const Icon(Icons.folder_open, size: 15, color: AppColors.primary),
            const SizedBox(width: 4),
            Flexible(
                child: Text(cat.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.titleSm.copyWith(color: AppColors.primary))),
          ]),
        ),
        PopupMenuButton<String>(
            tooltip: 'Folder options',
            onSelected: (v) {
              if (v == 'edit') showFolderDialog(context, existing: cat);
              if (v == 'delete') _delete(cat);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Rename / edit folder')),
              PopupMenuItem(value: 'delete', child: Text('Delete folder')),
            ],
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.more_vert, size: 18, color: AppColors.onSurfaceVariant),
            ),
          ),
      ]),
      const SizedBox(height: 12),

      // Folder header card
      Container(
        decoration: AppDeco.card(),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            height: 6,
            decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryContainer, AppColors.primary, AppColors.secondary])),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: lowCount > 0 ? AppColors.errorContainer : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.science_outlined,
                      size: 26, color: lowCount > 0 ? AppColors.onErrorContainer : AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat.name, style: AppText.headlineSm),
                    Text(
                        '${(cat.description ?? '').isEmpty ? '' : '${cat.description} • '}${inFolder.length} Item${inFolder.length == 1 ? '' : 's'}',
                        style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  ]),
                ),
                if (lowCount > 0) Pill('$lowCount low', bg: AppColors.errorContainer, fg: AppColors.onErrorContainer),
              ]),
              if ((cat.location ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.shelves, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(cat.location!, style: AppText.titleSm)),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/chemicals/new?category=${cat.id}'),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Chemical'),
                ),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Filter + sort + view
      TextField(
        controller: _filter,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Filter by name, formula, grade, shelf...',
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _filter.text.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(_filter.clear)),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: PopupMenuButton<ChemSort>(
            tooltip: 'Sort',
            initialValue: sort,
            onSelected: (s) => ref.read(chemSortProvider.notifier).state = s,
            itemBuilder: (_) => [for (final s in ChemSort.values) PopupMenuItem(value: s, child: Text(s.label))],
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: AppDeco.card(radius: 8),
              child: Row(children: [
                const Icon(Icons.swap_vert, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(sort.label, overflow: TextOverflow.ellipsis, style: AppText.titleSm)),
                const Icon(Icons.expand_more, size: 16, color: AppColors.outline),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            _viewBtn(Icons.format_list_bulleted, !grid, () => ref.read(chemGridProvider.notifier).state = false),
            _viewBtn(Icons.grid_view, grid, () => ref.read(chemGridProvider.notifier).state = true),
          ]),
        ),
      ]),
      const SizedBox(height: 12),

      if (inFolder.isEmpty)
        EmptyState(
          icon: Icons.science_outlined,
          title: 'No chemicals in this folder yet.',
          actionLabel: '+ Add Chemical',
          onAction: () => context.push('/chemicals/new?category=${cat.id}'),
        )
      else if (shown.isEmpty)
        const EmptyState(icon: Icons.search_off, title: 'No matches', message: 'Try a different filter.')
      else if (grid)
        LayoutBuilder(builder: (context, box) {
          final cols = Responsive.gridColumns(box.maxWidth + 32, compact: 1);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols == 1 ? 2 : cols, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 138),
            itemBuilder: (_, i) => FileCard(
                chemical: shown[i], compact: true, onTap: () => context.push('/chemicals/${shown[i].id}')),
          );
        })
      else
        Column(children: [
          for (final c in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FileCard(chemical: c, onTap: () => context.push('/chemicals/${c.id}')),
            ),
        ]),

      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Showing ${shown.length} of ${inFolder.length} logged files',
            style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
        if (inFolder.isNotEmpty)
          TextButton.icon(
            onPressed: () => copyCsv(context, _csv(inFolder), label: '${cat.name} ledger CSV'),
            icon: const Icon(Icons.file_download_outlined, size: 14),
            label: Text('Export ${cat.name} (.CSV)', style: AppText.monoSm),
          ),
      ]),
    ]);
  }

  String _csv(List<ChemicalModel> list) => toCsv(
        ['Name', 'Formula', 'CAS', 'Current', 'Unit', 'Minimum', 'Status', 'Location'],
        [
          for (final c in list)
            [
              c.name,
              c.formula,
              c.casNumber ?? '',
              Fmt.qty(c.currentStock),
              c.unit,
              Fmt.qty(c.minimumStock),
              c.status.name,
              c.location ?? '',
            ]
        ],
      );

  Widget _squareBtn(IconData icon, VoidCallback onTap, String tip) => Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18),
          ),
        ),
      );

  Widget _viewBtn(IconData i, bool sel, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: sel ? AppColors.surfaceLowest : Colors.transparent, borderRadius: BorderRadius.circular(6)),
          child: Icon(i, size: 18, color: sel ? AppColors.primary : AppColors.onSurfaceVariant),
        ),
      );
}
