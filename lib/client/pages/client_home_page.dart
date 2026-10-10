import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../models/category_model.dart';
import '../../models/chemical_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../widgets/common_states.dart';
import '../../widgets/folder_card.dart';
import '../widgets/client_search_results.dart';

/// Client home: the laboratory's "Lab Root / Chemical Records" folder grid, read-only.
/// Folders and counts come from the same Firestore collections the laboratory app uses.
class ClientHomePage extends ConsumerStatefulWidget {
  const ClientHomePage({super.key});
  @override
  ConsumerState<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends ConsumerState<ClientHomePage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim();
    return PageContainer(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        _breadcrumb(),
        const SizedBox(height: 12),
        _searchBox(),
        const SizedBox(height: 16),
        if (q.isNotEmpty) ClientSearchResults(query: q) else _folderSection(),
      ]),
    );
  }

  Widget _breadcrumb() => Row(children: [
        const Icon(Icons.home_work_outlined, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text('Lab Root', style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
        Text(' / ', style: AppText.monoSm.copyWith(color: AppColors.outlineVariant)),
        Text('Chemical Records', style: AppText.titleSm),
      ]);

  Widget _searchBox() => Container(
        decoration: AppDeco.card(radius: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          const Icon(Icons.search, size: 20, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: AppText.bodyMd.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search chemicals or formulas (e.g. HCl)...',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintStyle: AppText.bodyMd.copyWith(color: AppColors.outline),
              ),
            ),
          ),
          if (_search.text.isNotEmpty)
            IconButton(
                tooltip: 'Clear search',
                onPressed: () => setState(_search.clear),
                icon: const Icon(Icons.close, size: 18)),
        ]),
      );

  Widget _folderSection() {
    final cats = ref.watch(categoriesProvider);
    final chems = ref.watch(chemicalsProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text('Folders', style: AppText.titleMd),
      ]),
      const SizedBox(height: 8),
      AsyncBody<List<CategoryModel>>(
        value: cats,
        onRetry: () => ref.invalidate(categoriesProvider),
        data: (folders) => AsyncBody<List<ChemicalModel>>(
          value: chems,
          onRetry: () => ref.invalidate(chemicalsProvider),
          data: (all) => _grid(folders, all),
        ),
      ),
    ]);
  }

  Widget _grid(List<CategoryModel> folders, List<ChemicalModel> all) {
    if (folders.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open,
        title: 'No folders yet',
        message: 'The laboratory has not added any chemical folders yet.',
      );
    }
    // Same folder statistics the laboratory app uses, minus the staff-only low-stock count.
    final stats = FolderStats.build(all);
    FolderStats statsFor(String id) {
      final s = stats[id];
      return s == null ? const FolderStats() : FolderStats(count: s.count, formulas: s.formulas);
    }

    return LayoutBuilder(builder: (context, box) {
      final cols = Responsive.gridColumns(box.maxWidth + 32);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: folders.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 168),
        itemBuilder: (_, i) => FolderCard(
          category: folders[i],
          stats: statsFor(folders[i].id),
          onTap: () => context.go('/folder/${folders[i].id}'),
        ),
      );
    });
  }
}
