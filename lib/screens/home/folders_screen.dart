import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../models/category_model.dart';
import '../../models/chemical_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/ui_providers.dart';
import '../../widgets/common_states.dart';
import '../../widgets/dialogs/folder_dialog.dart';
import '../../widgets/folder_card.dart';
import '../../widgets/ledger_tile.dart';
import 'search_screen.dart';

/// Home: "Lab Root / Chemical Records" — the top level of the file manager.
class FoldersScreen extends ConsumerStatefulWidget {
  const FoldersScreen({super.key});
  @override
  ConsumerState<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends ConsumerState<FoldersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _seed(String uid) async {
    try {
      await ref.read(categoryRepositoryProvider).seedDefaults(uid);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserProvider)?.uid;
    final cats = ref.watch(categoriesProvider);
    final chems = ref.watch(chemicalsProvider);
    final allChems = chems.valueOrNull ?? const <ChemicalModel>[];
    final q = _search.text.trim();

    return PageContainer(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        _crumbAndStats(cats.valueOrNull?.length ?? 0, allChems),
        const SizedBox(height: 12),
        _searchBox(),
        const SizedBox(height: 12),
        if (q.isNotEmpty)
          SearchResultsView(query: q)
        else ...[
          _filterRow(),
          const SizedBox(height: 12),
          _actions(context),
          const SizedBox(height: 16),
          _folderSection(cats, allChems, uid),
          const SizedBox(height: 20),
          _quickLedger(),
        ],
      ]),
    );
  }

  Widget _crumbAndStats(int folderCount, List<ChemicalModel> chems) {
    final low = chems.where((c) => c.isLow).length;
    Widget stat(IconData i, Color ic, String n, String label, {Color bg = AppColors.surfaceContainer, Color fg = AppColors.onSurface}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 15, color: ic),
            const SizedBox(width: 6),
            Text(n, style: AppText.monoSm.copyWith(color: fg, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Text(label, style: AppText.monoSm.copyWith(color: fg)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.home_work_outlined, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text('Lab Root', style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
        Text(' / ', style: AppText.monoSm.copyWith(color: AppColors.outlineVariant)),
        Text('Chemical Records', style: AppText.titleSm),
      ]),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          stat(Icons.folder_outlined, AppColors.primary, '$folderCount', 'Categories'),
          const SizedBox(width: 6),
          stat(Icons.science_outlined, AppColors.secondary, '${chems.length}', 'Reagents'),
          if (low > 0) ...[
            const SizedBox(width: 6),
            stat(Icons.notification_important_outlined, AppColors.error, '$low', 'Low Stock',
                bg: AppColors.errorContainer, fg: AppColors.onErrorContainer),
          ],
        ]),
      ),
    ]);
  }

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
                hintText: 'Search chemicals, CAS, formulas (e.g. HCl)...',
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
                onPressed: () => setState(_search.clear),
                icon: const Icon(Icons.close, size: 18)),
        ]),
      );

  Widget _filterRow() {
    final tag = ref.watch(homeTagFilterProvider);
    final grid = ref.watch(folderGridProvider);

    Widget chip(String label, String? value) {
      final sel = tag == value;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () => ref.read(homeTagFilterProvider.notifier).state = value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(99)),
            child: Text(label,
                style: AppText.monoSm.copyWith(
                    color: sel ? Colors.white : AppColors.onSurfaceVariant,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w500)),
          ),
        ),
      );
    }

    Widget toggle(IconData i, bool isGrid) {
      final sel = grid == isGrid;
      return GestureDetector(
        onTap: () => ref.read(folderGridProvider.notifier).state = isGrid,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: sel ? AppColors.surfaceLowest : Colors.transparent,
              borderRadius: BorderRadius.circular(6)),
          child: Icon(i, size: 16, color: sel ? AppColors.primary : AppColors.onSurfaceVariant),
        ),
      );
    }

    return Row(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [chip('All', null), for (final t in chemicalTags) chip(t, t)]),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [toggle(Icons.grid_view, true), toggle(Icons.format_list_bulleted, false)]),
      ),
    ]);
  }

  Widget _actions(BuildContext context) => Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => context.push('/chemicals/new'),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('New Chemical'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: AppColors.surfaceHigh,
                foregroundColor: AppColors.onSurface),
            onPressed: () => showFolderDialog(context),
            icon: const Icon(Icons.create_new_folder_outlined, size: 18, color: AppColors.primary),
            label: const Text('New Folder'),
          ),
        ),
      ]);

  Widget _folderSection(AsyncValue<List<CategoryModel>> cats, List<ChemicalModel> allChems, String? uid) {
    final sort = ref.watch(folderSortProvider);
    final grid = ref.watch(folderGridProvider);
    final tag = ref.watch(homeTagFilterProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('Classified Storage Folders', style: AppText.titleMd),
        ]),
        PopupMenuButton<FolderSort>(
          tooltip: 'Sort folders',
          initialValue: sort,
          onSelected: (s) => ref.read(folderSortProvider.notifier).state = s,
          itemBuilder: (_) => [for (final s in FolderSort.values) PopupMenuItem(value: s, child: Text(s.label))],
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Sort: ', style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
            Text(sort.label, style: AppText.monoSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
            const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
          ]),
        ),
      ]),
      const SizedBox(height: 8),
      AsyncBody<List<CategoryModel>>(
        value: cats,
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open,
              title: 'No folders yet',
              message: 'Create folders to organise your chemical records.',
              actionLabel: '+ Create default folders',
              onAction: uid != null ? () => _seed(uid) : null,
              secondaryLabel: '+ New Folder',
              onSecondary: () => showFolderDialog(context),
            );
          }
          final scoped = tag == null ? allChems : allChems.where((c) => c.tags.contains(tag)).toList();
          final stats = FolderStats.build(scoped);
          var shown = tag == null ? [...list] : list.where((c) => stats.containsKey(c.id)).toList();
          int items(CategoryModel c) => stats[c.id]?.count ?? 0;
          int lows(CategoryModel c) => stats[c.id]?.low ?? 0;
          switch (sort) {
            case FolderSort.nameAsc:
              shown.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            case FolderSort.nameDesc:
              shown.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
            case FolderSort.mostItems:
              shown.sort((a, b) => items(b).compareTo(items(a)));
            case FolderSort.lowFirst:
              shown.sort((a, b) => lows(b).compareTo(lows(a)));
          }
          if (shown.isEmpty) {
            return EmptyState(
                icon: Icons.filter_alt_off_outlined, title: 'No folders match "$tag"', message: 'Try another filter.');
          }
          void open(CategoryModel c) => context.go('/folders/${c.id}');
          if (!grid) {
            return Column(children: [
              for (final c in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FolderListTile(category: c, stats: stats[c.id] ?? const FolderStats(), onTap: () => open(c)),
                ),
            ]);
          }
          return LayoutBuilder(builder: (context, box) {
            final cols = Responsive.gridColumns(box.maxWidth + 32);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shown.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 168),
              itemBuilder: (_, i) => FolderCard(
                  category: shown[i], stats: stats[shown[i].id] ?? const FolderStats(), onTap: () => open(shown[i])),
            );
          });
        },
      ),
    ]);
  }

  Widget _quickLedger() {
    final recent = ref.watch(recentTransactionsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          const Icon(Icons.history_edu, size: 18, color: AppColors.secondary),
          const SizedBox(width: 6),
          Text("Today's Quick Ledger", style: AppText.titleMd),
        ]),
        TextButton(onPressed: () => context.go('/recents'), child: const Text('View All ›')),
      ]),
      recent.when(
        loading: () => const LoadingView(padding: EdgeInsets.all(16)),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (list) {
          final today = list.where((t) => Fmt.isToday(t.sortTime)).take(5).toList();
          if (today.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppDeco.card(),
              child: Text('No entries recorded today.',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
            );
          }
          return Container(
            decoration: AppDeco.card(),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < today.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.surfaceContainer),
                LedgerTile(entry: today[i], onTap: () => context.push('/chemicals/${today[i].chemicalId}')),
              ],
            ]),
          );
        },
      ),
    ]);
  }
}
